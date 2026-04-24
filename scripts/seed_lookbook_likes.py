#!/usr/bin/env python3
"""
Distribute lookbook likes across seeded posts using the seed username lists.

  • Loads poster + liker accounts from ``scripts/data/seed-usernames-male.txt`` and
    ``seed-usernames-female.txt`` (override with ``--male-list`` / ``--female-list``).
  • Fetches all lookbook posts from the API (paginated ``lookbooks`` query).
  • Assigns each post a **target like count** in ``[0, max_likes]`` with a skewed distribution
    (many posts get few likes, some get more - simulates uneven engagement). Default **max 27**.
  • For each post, picks that many **distinct** likers at random, excluding the poster
    (users cannot like their own post).
  • Logs in **once per liker** and applies likes for all assigned posts: queries ``userLiked``,
    then ``toggleLookbookLike`` only when not already liked (idempotent re-runs).

  Required env: ``STAGING_SEED_PASSWORD``. Optional: ``GRAPHQL_URL``, ``SEED_EMAIL_DOMAIN``,
  ``SEED_RANDOM_SEED`` (integer for reproducible sampling - **set this** if you stop and re-run so
  the like plan matches and the checkpoint can resume). If you omit it, the script picks a seed,
  prints it, and saves it to ``scripts/data/lookbook_likes_last_random_seed.txt``; use
  ``--reuse-saved-seed`` on the next run to reuse that file without setting the env var.

  Progress is persisted under ``scripts/data/lookbook_likes_seed_checkpoint.json`` (see
  ``--checkpoint`` / ``--no-checkpoint``): completed edges are skipped on the next run and the
  progress line starts from how many edges were already finished.

  Example::

    STAGING_SEED_PASSWORD='…' python3 scripts/seed_lookbook_likes.py

  Dry run (plan only, no mutations)::

    STAGING_SEED_PASSWORD='…' python3 scripts/seed_lookbook_likes.py --dry-run
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import random
import secrets
import sys
import time
from collections import defaultdict
from pathlib import Path
from typing import Any

from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

DEFAULT_GRAPHQL = "https://prelura.voltislabs.uk/graphql/"
SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_MALE_LIST = SCRIPT_DIR / "data" / "seed-usernames-male.txt"
DEFAULT_FEMALE_LIST = SCRIPT_DIR / "data" / "seed-usernames-female.txt"
DEFAULT_CHECKPOINT = SCRIPT_DIR / "data" / "lookbook_likes_seed_checkpoint.json"
LAST_RANDOM_SEED_FILE = SCRIPT_DIR / "data" / "lookbook_likes_last_random_seed.txt"
CHECKPOINT_VERSION = 1

LOGIN_MUTATION = """mutation Login($username: String!, $password: String!) {
  login(username: $username, password: $password) {
    token refreshToken user { id username email }
  }
}"""

# Staging often exposes Relay-style connections **without** `pageInfo` on `LookbooksConnectionType`.
# Use a single-page query first (matches LookbookService `fetchLookbooks` fallback).
LOOKBOOKS_SIMPLE = """query Lookbooks($first: Int) {
  lookbooks(first: $first) {
    nodes { id username }
    edges { node { id username } }
  }
}"""

# When the schema supports cursor pagination + pageInfo (newer API).
LOOKBOOKS_PAGED = """query LookbooksFeed($first: Int, $after: String) {
  lookbooks(first: $first, after: $after) {
    pageInfo { hasNextPage endCursor }
    nodes { id username }
    edges { node { id username } }
  }
}"""

LOOKBOOK_POST_LIKED = """query LookbookPostLiked($postId: UUID!) {
  lookbookPost(postId: $postId) {
    id
    userLiked
  }
}"""

TOGGLE_LOOKBOOK_LIKE = """mutation ToggleLookbookLike($postId: UUID!) {
  toggleLookbookLike(postId: $postId) {
    success
    liked
    likesCount
    message
  }
}"""


def graphql_json(url: str, payload: dict[str, Any], token: str | None = None) -> dict[str, Any]:
    data = json.dumps(payload).encode("utf-8")
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = Request(url, data=data, headers=headers, method="POST")
    try:
        with urlopen(req, timeout=180) as resp:
            body = resp.read().decode("utf-8")
    except HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        try:
            parsed = json.loads(body)
            if isinstance(parsed, dict):
                return parsed
        except json.JSONDecodeError:
            pass
        raise SystemExit(f"HTTP {e.code}: {body[:2500]}") from e
    except URLError as e:
        raise SystemExit(f"Network: {e}") from e
    return json.loads(body)


def login(graphql_url: str, password: str, username: str, email_domain: str) -> str:
    payload = {"query": LOGIN_MUTATION, "variables": {"username": username, "password": password}}
    r = graphql_json(graphql_url, payload)
    if r.get("errors") and "@" not in username:
        payload["variables"] = {"username": f"{username}@{email_domain}", "password": password}
        r = graphql_json(graphql_url, payload)
    if r.get("errors"):
        raise RuntimeError(json.dumps(r["errors"]))
    tok = (r.get("data") or {}).get("login", {}).get("token")
    if not tok:
        raise RuntimeError("no token")
    return tok


def load_usernames(path: Path) -> list[str]:
    if not path.is_file():
        raise SystemExit(f"Username list not found: {path}")
    out: list[str] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        u = line.strip()
        if u and not u.startswith("#"):
            out.append(u)
    return out


def _extend_posts_from_conn(
    conn: dict[str, Any],
    merged: list[dict[str, str]],
    seen: set[str],
    max_posts: int,
) -> None:
    batch: list[dict[str, Any]] = []
    if conn.get("nodes"):
        batch = [x for x in conn["nodes"] if x]
    elif conn.get("edges"):
        batch = [e["node"] for e in conn["edges"] if e and e.get("node")]
    for row in batch:
        if len(merged) >= max_posts:
            return
        pid = str(row.get("id") or "").strip()
        un = str(row.get("username") or "").strip()
        if not pid:
            continue
        if pid not in seen:
            seen.add(pid)
            merged.append({"id": pid, "username": un})


# Max ``first`` for a single lookbooks request when the connection has no ``pageInfo`` (staging).
LOOKBOOKS_SINGLE_REQUEST_CAP = 50_000


def fetch_all_lookbook_posts(
    graphql_url: str,
    token: str,
    *,
    page_size: int,
    max_posts: int,
) -> list[dict[str, str]]:
    """Return list of {id, username} for each post (poster username).

    Tries **cursor pagination** first when the schema exposes ``pageInfo``; otherwise one large
    ``first`` (up to :data:`LOOKBOOKS_SINGLE_REQUEST_CAP`) so staging returns the full feed, not only ~500 rows.
    """
    merged: list[dict[str, str]] = []
    seen: set[str] = set()

    # 1) Paginated query when the API exposes pageInfo + after (full feed).
    cursor: str | None = None
    iterations = 0
    while len(merged) < max_posts and iterations < 500:
        iterations += 1
        variables: dict[str, Any] = {"first": min(page_size, max(1, max_posts - len(merged)))}
        if cursor:
            variables["after"] = cursor
        else:
            variables["after"] = None
        r2 = graphql_json(
            graphql_url,
            {
                "query": LOOKBOOKS_PAGED,
                "variables": variables,
                "operationName": "LookbooksFeed",
            },
            token=token,
        )
        if r2.get("errors"):
            err_txt = json.dumps(r2["errors"]).lower()
            if "pageinfo" in err_txt or "cannot query field" in err_txt:
                break
            raise RuntimeError(json.dumps(r2["errors"]))
        conn = (r2.get("data") or {}).get("lookbooks") or {}
        before = len(merged)
        _extend_posts_from_conn(conn, merged, seen, max_posts)
        if len(merged) >= max_posts:
            return merged
        if len(merged) == before:
            return merged
        pi = conn.get("pageInfo") or {}
        has_next = pi.get("hasNextPage") is True
        end = (pi.get("endCursor") or "").strip()
        if not has_next or not end:
            return merged
        cursor = end

    if merged:
        return merged

    # 2) Single request without pageInfo (many staging schemas omit it on LookbooksConnection).
    first_cap = min(max(1, max_posts), LOOKBOOKS_SINGLE_REQUEST_CAP)
    r = graphql_json(
        graphql_url,
        {
            "query": LOOKBOOKS_SIMPLE,
            "variables": {"first": first_cap},
            "operationName": "Lookbooks",
        },
        token=token,
    )
    if r.get("errors"):
        raise RuntimeError(json.dumps(r["errors"]))
    conn = (r.get("data") or {}).get("lookbooks") or {}
    _extend_posts_from_conn(conn, merged, seen, max_posts)
    return merged


def sample_target_likes(rng: random.Random, cap: int) -> int:
    """Skewed integer in [0, cap]: many posts with few likes, long tail toward cap."""
    if cap <= 0:
        return 0
    # ~12% stay at 0 (lurkers / low visibility)
    if rng.random() < 0.12:
        return 0
    u = rng.random()
    if u < 0.48:
        lo, hi = 1, max(1, cap // 4)
    elif u < 0.82:
        lo = max(1, cap // 4 + 1)
        hi = max(lo, (cap * 2) // 3)
    else:
        lo = max(1, (cap * 2) // 3)
        hi = cap
    if lo > hi:
        lo, hi = hi, lo
    return rng.randint(lo, hi)


def build_like_plan(
    posts: list[dict[str, str]],
    all_users: list[str],
    rng: random.Random,
    max_likes_per_post: int,
) -> tuple[dict[str, list[str]], dict[str, Any]]:
    """
    Returns (liker_username -> [post_id, ...], stats dict).
    Each post gets ``sample_target_likes`` distinct likers (excluding poster).
    """
    user_lower = {u.lower(): u for u in all_users}
    liker_to_posts: dict[str, list[str]] = defaultdict(list)
    targets: list[int] = []
    skipped_no_pool = 0

    for post in posts:
        pid = post["id"]
        poster = (post.get("username") or "").strip()
        poster_l = poster.lower()
        pool = [user_lower[k] for k in user_lower if k != poster_l]
        if not pool:
            skipped_no_pool += 1
            continue
        k = sample_target_likes(rng, max_likes_per_post)
        k = min(k, len(pool))
        targets.append(k)
        if k == 0:
            continue
        chosen = rng.sample(pool, k)
        for liker in chosen:
            liker_to_posts[liker].append(pid)

    stats = {
        "posts_total": len(posts),
        "max_likes_per_post": max_likes_per_post,
        "target_likes_histogram": _histogram(targets),
        "posts_with_zero_target": sum(1 for t in targets if t == 0),
        "unique_likers": len(liker_to_posts),
        "total_like_edges": sum(len(v) for v in liker_to_posts.values()),
        "skipped_no_liker_pool": skipped_no_pool,
    }
    return dict(liker_to_posts), stats


def _histogram(values: list[int]) -> dict[str, int]:
    h: dict[str, int] = {}
    for v in values:
        key = str(v)
        h[key] = h.get(key, 0) + 1
    return dict(sorted(h.items(), key=lambda x: int(x[0])))


def edge_key(liker: str, post_id: str) -> str:
    return f"{liker}\t{post_id}"


def resolve_rng_seed(
    *,
    env_value: str | None,
    reuse_saved: bool,
    last_seed_path: Path,
) -> tuple[random.Random, int, str]:
    """Build RNG from env, optional saved file, or a new secret seed (persisted to file)."""
    env = (env_value or "").strip()
    if env.isdigit():
        s = int(env)
        last_seed_path.parent.mkdir(parents=True, exist_ok=True)
        last_seed_path.write_text(f"{s}\n", encoding="utf-8")
        return random.Random(s), s, "SEED_RANDOM_SEED"
    if reuse_saved and last_seed_path.is_file():
        try:
            line = last_seed_path.read_text(encoding="utf-8").strip().splitlines()[0]
            if line.isdigit():
                s = int(line)
                return random.Random(s), s, f"file {last_seed_path.name}"
        except (OSError, IndexError, ValueError):
            pass
    s = secrets.randbelow(1 << 31)
    last_seed_path.parent.mkdir(parents=True, exist_ok=True)
    last_seed_path.write_text(f"{s}\n", encoding="utf-8")
    return random.Random(s), s, "generated (saved to data/lookbook_likes_last_random_seed.txt)"


def plan_fingerprint(liker_to_posts: dict[str, list[str]]) -> str:
    """Stable hash so the same assignment graph resumes from checkpoint."""
    normalized: dict[str, list[str]] = {}
    for liker in sorted(liker_to_posts.keys()):
        normalized[liker] = sorted(liker_to_posts[liker])
    payload = json.dumps(normalized, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def load_checkpoint(path: Path) -> tuple[str | None, set[str]]:
    if not path.is_file():
        return None, set()
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return None, set()
    if raw.get("version") != CHECKPOINT_VERSION:
        return None, set()
    fp = raw.get("plan_fingerprint")
    if not isinstance(fp, str) or not fp:
        return None, set()
    done = raw.get("completed") or []
    if not isinstance(done, list):
        return None, set()
    return fp, {str(x) for x in done}


def save_checkpoint(path: Path, plan_fp: str, completed: set[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(
        json.dumps(
            {
                "version": CHECKPOINT_VERSION,
                "plan_fingerprint": plan_fp,
                "completed": sorted(completed),
            },
            separators=(",", ":"),
        ),
        encoding="utf-8",
    )
    tmp.replace(path)


def _report_like_progress(
    *,
    done_count: int,
    scan: int,
    total: int,
    applied: int,
    skipped_already: int,
    is_tty: bool,
    every: int,
) -> None:
    """Stderr: live line on TTY; periodic lines when not a TTY."""
    if total <= 0:
        return
    if not is_tty and scan % every != 0 and scan != total:
        return
    pct = 100.0 * min(done_count, total) / total
    msg = (
        f"Progress: {pct:5.1f}% ({done_count}/{total} done, pass {scan}/{total}) | "
        f"new likes: {applied} | skipped (already liked): {skipped_already}"
    )
    if is_tty:
        sys.stderr.write("\r" + msg.ljust(132))
        sys.stderr.flush()
    else:
        sys.stderr.write(msg + "\n")
        sys.stderr.flush()


def lookbook_user_liked(graphql_url: str, token: str, post_id: str) -> bool | None:
    r = graphql_json(
        graphql_url,
        {
            "query": LOOKBOOK_POST_LIKED,
            "variables": {"postId": post_id},
            "operationName": "LookbookPostLiked",
        },
        token=token,
    )
    if r.get("errors"):
        return None
    lp = (r.get("data") or {}).get("lookbookPost")
    if not lp:
        return None
    return bool(lp.get("userLiked"))


def toggle_like(graphql_url: str, token: str, post_id: str) -> tuple[bool, str | None]:
    r = graphql_json(
        graphql_url,
        {
            "query": TOGGLE_LOOKBOOK_LIKE,
            "variables": {"postId": post_id},
            "operationName": "ToggleLookbookLike",
        },
        token=token,
    )
    if r.get("errors"):
        return False, json.dumps(r["errors"])
    pl = (r.get("data") or {}).get("toggleLookbookLike") or {}
    if not pl.get("success"):
        return False, pl.get("message")
    liked = pl.get("liked")
    return liked is True, None


def main() -> None:
    parser = argparse.ArgumentParser(description="Seed skewed lookbook likes across seed users.")
    parser.add_argument("--graphql-url", default=os.environ.get("GRAPHQL_URL", DEFAULT_GRAPHQL))
    parser.add_argument("--male-list", type=Path, default=DEFAULT_MALE_LIST)
    parser.add_argument("--female-list", type=Path, default=DEFAULT_FEMALE_LIST)
    parser.add_argument("--max-likes-per-post", type=int, default=27, help="No post receives more than this many likes.")
    parser.add_argument("--max-posts", type=int, default=10_000, help="Stop after this many posts from the API.")
    parser.add_argument("--page-size", type=int, default=100)
    parser.add_argument("--dry-run", action="store_true", help="Fetch posts and print plan; no likes.")
    parser.add_argument("--sleep-ms", type=int, default=0, help="Optional delay between GraphQL calls (rate limits).")
    parser.add_argument(
        "--progress-every",
        type=int,
        default=1,
        metavar="N",
        help="When stderr is not a terminal, print progress every N edges (default 1). Ignored for TTY (updates every edge).",
    )
    parser.add_argument(
        "--checkpoint",
        type=Path,
        default=DEFAULT_CHECKPOINT,
        help=f"Resume file for finished liker+post edges (default: {DEFAULT_CHECKPOINT}).",
    )
    parser.add_argument(
        "--no-checkpoint",
        action="store_true",
        help="Do not read or write the checkpoint file.",
    )
    parser.add_argument(
        "--reuse-saved-seed",
        action="store_true",
        help=(
            "If SEED_RANDOM_SEED is unset, use the integer from "
            "data/lookbook_likes_last_random_seed.txt (written on the last run that generated a seed)."
        ),
    )
    args = parser.parse_args()

    password = os.environ.get("STAGING_SEED_PASSWORD")
    if not password:
        print("Set STAGING_SEED_PASSWORD", file=sys.stderr)
        sys.exit(1)
    email_domain = os.environ.get("SEED_EMAIL_DOMAIN", "prelura.com")
    graphql_url = args.graphql_url.rstrip("/") + "/"

    rng, resolved_seed, seed_source = resolve_rng_seed(
        env_value=os.environ.get("SEED_RANDOM_SEED"),
        reuse_saved=args.reuse_saved_seed,
        last_seed_path=LAST_RANDOM_SEED_FILE,
    )
    print(
        f"Random seed: {resolved_seed} ({seed_source}). "
        f"Re-run with the same plan: export SEED_RANDOM_SEED={resolved_seed}"
    )

    males = load_usernames(args.male_list)
    females = load_usernames(args.female_list)
    all_users = list(dict.fromkeys(males + females))  # preserve order, dedupe

    if len(all_users) < 2:
        print("Need at least 2 seed usernames.", file=sys.stderr)
        sys.exit(1)

    # Login as first user only to list posts (any authenticated session that can read the feed).
    first_tok = login(graphql_url, password, all_users[0], email_domain)
    posts = fetch_all_lookbook_posts(
        graphql_url, first_tok, page_size=args.page_size, max_posts=args.max_posts
    )
    print(f"Fetched {len(posts)} lookbook post(s).")

    liker_to_posts, stats = build_like_plan(posts, all_users, rng, args.max_likes_per_post)
    print("Plan stats:", json.dumps(stats, indent=2))

    summary_path = SCRIPT_DIR / "data" / "lookbook_likes_seed_summary.json"
    summary_path.parent.mkdir(parents=True, exist_ok=True)

    if args.dry_run:
        summary = {
            "dry_run": True,
            "stats": stats,
            "graphql_url": graphql_url,
            "random_seed": resolved_seed,
            "random_seed_source": seed_source,
        }
        summary_path.write_text(json.dumps(summary, indent=2), encoding="utf-8")
        print(f"Wrote {summary_path}")
        return

    sleep_s = max(0.0, args.sleep_ms / 1000.0)
    applied = 0
    skipped_already = 0
    errors: list[dict[str, Any]] = []

    total_edges = int(stats.get("total_like_edges") or 0)
    scan = 0
    progress_tty = sys.stderr.isatty()
    prog_every = max(1, args.progress_every)

    checkpoint_path: Path | None = None if args.no_checkpoint else args.checkpoint
    plan_fp = plan_fingerprint(liker_to_posts)
    plan_keys = {edge_key(liker, pid) for liker, ids in liker_to_posts.items() for pid in ids}

    completed_keys: set[str] = set()
    if checkpoint_path:
        loaded_fp, loaded_done = load_checkpoint(checkpoint_path)
        if loaded_fp == plan_fp:
            completed_keys = {k for k in loaded_done if k in plan_keys}
        elif loaded_fp is not None:
            sys.stderr.write(
                "Checkpoint ignored: plan fingerprint does not match this run. "
                "Use the same SEED_RANDOM_SEED, username lists, fetched posts, and "
                "--max-likes-per-post so the assignment matches your last checkpoint.\n"
            )
            sys.stderr.flush()

    if total_edges > 0:
        sys.stderr.write("Applying likes (progress on stderr)…\n")
        if checkpoint_path and completed_keys:
            sys.stderr.write(
                f"Resuming: {len(completed_keys)}/{total_edges} edges already marked done in checkpoint.\n"
            )
        sys.stderr.flush()

    for liker in sorted(liker_to_posts.keys()):
        post_ids = liker_to_posts[liker]
        pending = [pid for pid in post_ids if edge_key(liker, pid) not in completed_keys]
        if not pending:
            for _pid in post_ids:
                scan += 1
                _report_like_progress(
                    done_count=len(completed_keys),
                    scan=scan,
                    total=total_edges,
                    applied=applied,
                    skipped_already=skipped_already,
                    is_tty=progress_tty,
                    every=prog_every,
                )
            continue

        try:
            tok = login(graphql_url, password, liker, email_domain)
        except Exception as e:
            errors.append({"liker": liker, "phase": "login", "error": str(e)})
            scan += len(post_ids)
            _report_like_progress(
                done_count=len(completed_keys),
                scan=scan,
                total=total_edges,
                applied=applied,
                skipped_already=skipped_already,
                is_tty=progress_tty,
                every=prog_every,
            )
            continue

        for pid in post_ids:
            scan += 1
            key = edge_key(liker, pid)
            if key in completed_keys:
                _report_like_progress(
                    done_count=len(completed_keys),
                    scan=scan,
                    total=total_edges,
                    applied=applied,
                    skipped_already=skipped_already,
                    is_tty=progress_tty,
                    every=prog_every,
                )
                continue

            if sleep_s:
                time.sleep(sleep_s)
            ul = lookbook_user_liked(graphql_url, tok, pid)
            if ul is True:
                skipped_already += 1
                completed_keys.add(key)
                if checkpoint_path:
                    save_checkpoint(checkpoint_path, plan_fp, completed_keys)
            elif ul is None:
                errors.append({"liker": liker, "postId": pid, "phase": "lookbookPost", "error": "missing or error"})
            else:
                ok, err = toggle_like(graphql_url, tok, pid)
                if ok:
                    applied += 1
                    completed_keys.add(key)
                    if checkpoint_path:
                        save_checkpoint(checkpoint_path, plan_fp, completed_keys)
                else:
                    errors.append({"liker": liker, "postId": pid, "phase": "toggle", "error": err or "not liked after toggle"})
            _report_like_progress(
                done_count=len(completed_keys),
                scan=scan,
                total=total_edges,
                applied=applied,
                skipped_already=skipped_already,
                is_tty=progress_tty,
                every=prog_every,
            )

    if total_edges > 0 and progress_tty:
        sys.stderr.write("\n")
        sys.stderr.flush()

    out = {
        "stats": stats,
        "likes_applied": applied,
        "skipped_already_liked": skipped_already,
        "errors": errors[:200],
        "error_count": len(errors),
        "graphql_url": graphql_url,
        "plan_fingerprint": plan_fp,
        "checkpoint_edges_done": len(completed_keys),
        "checkpoint_file": str(checkpoint_path) if checkpoint_path else None,
        "random_seed": resolved_seed,
        "random_seed_source": seed_source,
    }
    summary_path.write_text(json.dumps(out, indent=2), encoding="utf-8")
    print(
        json.dumps(
            {k: out[k] for k in ("likes_applied", "skipped_already_liked", "error_count", "checkpoint_edges_done")},
            indent=2,
        )
    )
    print(f"Summary: {summary_path}")
    if errors:
        sys.exit(1)


if __name__ == "__main__":
    main()
