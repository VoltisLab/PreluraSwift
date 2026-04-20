#!/usr/bin/env python3
"""
Seed **lookbook comment** likes on staging via GraphQL ``toggleLookbookCommentLike``.

Walks the global ``lookbooks`` feed, loads ``lookbookComments(postId)`` for each post that has
comments, then assigns a **target total like count** per comment (capped at **5**) using:

  • 10% → 5 likes  
  • 15% → 4 likes  
  • 10% → 3 likes  
  • 30% → 2 likes  
  • 35% → 1 like  

For each comment we only **add** likes (no unlikes). If the comment already has at least as many
likes as the sampled target, it is skipped. If it already has 5+, it is skipped.

Uses distinct likers from the male + female seed username lists (same pattern as
``seed_lookbook_likes.py``). A user never likes their own comment.

Requires ``STAGING_SEED_PASSWORD``. Optional: ``GRAPHQL_URL``, ``SEED_EMAIL_DOMAIN``,
``SEED_RANDOM_SEED`` (reproducible sampling).

**Scope:** lookbook comments only (not forum/chat). Run from repo root::

  STAGING_SEED_PASSWORD='…' python3 scripts/seed_lookbook_comment_likes.py --dry-run
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
import random
import sys
import time
from collections import defaultdict
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_MALE_LIST = SCRIPT_DIR / "data" / "seed-usernames-male.txt"
DEFAULT_FEMALE_LIST = SCRIPT_DIR / "data" / "seed-usernames-female.txt"
DEFAULT_CHECKPOINT = SCRIPT_DIR / "data" / "lookbook_comment_likes_checkpoint.json"
SUMMARY_PATH = SCRIPT_DIR / "data" / "lookbook_comment_likes_summary.json"
CHECKPOINT_VERSION = 1

# Cumulative thresholds for target total likes per comment (1..5).
TARGET_DISTRIBUTION: list[tuple[float, int]] = [
    (0.10, 5),
    (0.25, 4),  # 10% + 15%
    (0.35, 3),  # +10%
    (0.65, 2),  # +30%
    (1.00, 1),  # +35%
]

LOOKBOOKS_WITH_COUNT = """query Lookbooks($first: Int) {
  lookbooks(first: $first) {
    nodes { id username commentsCount }
    edges { node { id username commentsCount } }
  }
}"""

LOOKBOOKS_PAGED_COUNT = """query LookbooksFeed($first: Int, $after: String) {
  lookbooks(first: $first, after: $after) {
    pageInfo { hasNextPage endCursor }
    nodes { id username commentsCount }
    edges { node { id username commentsCount } }
  }
}"""

LOOKBOOK_COMMENTS = """query LookbookComments($postId: UUID!) {
  lookbookComments(postId: $postId) {
    id
    username
    likesCount
    userLiked
  }
}"""


def graphql_uuid(raw: str) -> str:
    """Match LookbookPostIdFormatting.graphQLUUIDString behaviour for GraphQL variables."""
    s = str(raw).strip()
    low = s.lower()
    if low.startswith("urn:uuid:"):
        s = s[len("urn:uuid:") :].strip()
    if len(s) >= 2 and s[0] == "{" and s[-1] == "}":
        s = s[1:-1].strip()
    hex_only = "".join(c for c in s if c in "0123456789abcdefABCDEF")
    if len(hex_only) == 32 and "-" not in s:
        h = hex_only.lower()
        s = f"{h[:8]}-{h[8:12]}-{h[12:16]}-{h[16:20]}-{h[20:]}"
    return s

TOGGLE_COMMENT_LIKE = """mutation ToggleLookbookCommentLike($commentId: UUID!) {
  toggleLookbookCommentLike(commentId: $commentId) {
    success
    message
    liked
    likesCount
  }
}"""


def _load_seed_lookbook_likes():
    path = SCRIPT_DIR / "seed_lookbook_likes.py"
    spec = importlib.util.spec_from_file_location("seed_lookbook_likes", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Cannot load {path}")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def sample_target_likes(rng: random.Random) -> int:
    u = rng.random()
    for hi, k in TARGET_DISTRIBUTION:
        if u < hi:
            return k
    return 1


def _extend_posts_count(
    conn: dict[str, Any],
    merged: list[dict[str, Any]],
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
        cc = row.get("commentsCount")
        try:
            cc_i = int(cc) if cc is not None else None
        except (TypeError, ValueError):
            cc_i = None
        if not pid:
            continue
        if pid not in seen:
            seen.add(pid)
            merged.append({"id": pid, "username": un, "commentsCount": cc_i})


def fetch_all_posts_with_comment_count(
    graphql_url: str,
    token: str,
    graphql_json,
    *,
    page_size: int,
    max_posts: int,
    single_cap: int,
) -> list[dict[str, Any]]:
    merged: list[dict[str, Any]] = []
    seen: set[str] = set()
    cursor: str | None = None
    iterations = 0
    while len(merged) < max_posts and iterations < 500:
        iterations += 1
        variables: dict[str, Any] = {"first": min(page_size, max(1, max_posts - len(merged)))}
        variables["after"] = cursor if cursor else None
        r2 = graphql_json(
            graphql_url,
            {
                "query": LOOKBOOKS_PAGED_COUNT,
                "variables": variables,
                "operationName": "LookbooksFeed",
            },
            token=token,
        )
        if r2.get("errors"):
            err_txt = json.dumps(r2.get("errors") or []).lower()
            if "pageinfo" in err_txt or "cannot query field" in err_txt:
                break
            raise RuntimeError(json.dumps(r2["errors"]))
        conn = (r2.get("data") or {}).get("lookbooks") or {}
        before = len(merged)
        _extend_posts_count(conn, merged, seen, max_posts)
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

    first_cap = min(max(1, max_posts), single_cap)
    r = graphql_json(
        graphql_url,
        {
            "query": LOOKBOOKS_WITH_COUNT,
            "variables": {"first": first_cap},
            "operationName": "Lookbooks",
        },
        token=token,
    )
    if r.get("errors"):
        err_txt = json.dumps(r.get("errors") or []).lower()
        if "commentscount" in err_txt and "cannot query" in err_txt:
            raise RuntimeError(
                "lookbooks does not expose commentsCount; backend must support it for this script "
                "(or extend fetch to omit commentsCount and scan all posts)."
            )
        raise RuntimeError(json.dumps(r["errors"]))
    conn = (r.get("data") or {}).get("lookbooks") or {}
    _extend_posts_count(conn, merged, seen, max_posts)
    return merged


def fetch_comments_for_post(graphql_url: str, token: str, post_id: str, graphql_json) -> list[dict[str, Any]]:
    normalized = graphql_uuid(post_id)
    r = graphql_json(
        graphql_url,
        {
            "query": LOOKBOOK_COMMENTS,
            "variables": {"postId": normalized},
            "operationName": "LookbookComments",
        },
        token=token,
    )
    if r.get("errors"):
        raise RuntimeError(json.dumps(r["errors"]))
    rows = (r.get("data") or {}).get("lookbookComments") or []
    out: list[dict[str, Any]] = []
    for row in rows:
        if not row:
            continue
        cid = str(row.get("id") or "").strip()
        if not cid:
            continue
        lc = row.get("likesCount")
        try:
            likes = int(lc) if lc is not None else 0
        except (TypeError, ValueError):
            likes = 0
        out.append(
            {
                "id": cid,
                "username": str(row.get("username") or "").strip(),
                "likesCount": likes,
                "userLiked": bool(row.get("userLiked")),
                "postId": post_id,
            }
        )
    return out


def toggle_comment_like(graphql_url: str, token: str, comment_id: str, graphql_json) -> tuple[bool, str | None]:
    normalized = graphql_uuid(comment_id)
    r = graphql_json(
        graphql_url,
        {
            "query": TOGGLE_COMMENT_LIKE,
            "variables": {"commentId": normalized},
            "operationName": "ToggleLookbookCommentLike",
        },
        token=token,
    )
    if r.get("errors"):
        return False, json.dumps(r["errors"])
    pl = (r.get("data") or {}).get("toggleLookbookCommentLike") or {}
    if not pl.get("success"):
        return False, pl.get("message")
    if pl.get("liked") is not True:
        return False, pl.get("message") or "not liked after toggle"
    return True, None


def plan_fingerprint(edges: list[tuple[str, str, str]]) -> str:
    """(liker, comment_id, post_id) sorted"""
    s = json.dumps(sorted([list(e) for e in edges]), separators=(",", ":"))
    return hashlib.sha256(s.encode("utf-8")).hexdigest()


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
    if not isinstance(fp, str):
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
            {"version": CHECKPOINT_VERSION, "plan_fingerprint": plan_fp, "completed": sorted(completed)},
            separators=(",", ":"),
        ),
        encoding="utf-8",
    )
    tmp.replace(path)


def edge_key(liker: str, comment_id: str) -> str:
    return f"{liker}\t{comment_id}"


def main() -> None:
    mod = _load_seed_lookbook_likes()

    parser = argparse.ArgumentParser(description="Seed lookbook comment likes with a fixed distribution.")
    parser.add_argument("--graphql-url", default=os.environ.get("GRAPHQL_URL", mod.DEFAULT_GRAPHQL))
    parser.add_argument("--male-list", type=Path, default=DEFAULT_MALE_LIST)
    parser.add_argument("--female-list", type=Path, default=DEFAULT_FEMALE_LIST)
    parser.add_argument("--max-posts", type=int, default=50_000)
    parser.add_argument("--page-size", type=int, default=100)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--sleep-ms", type=int, default=35)
    parser.add_argument("--checkpoint", type=Path, default=DEFAULT_CHECKPOINT)
    parser.add_argument("--no-checkpoint", action="store_true")
    parser.add_argument("--seed", type=int, default=None, help="Random seed for targets and liker picks.")
    args = parser.parse_args()

    password = os.environ.get("STAGING_SEED_PASSWORD")
    if not password:
        print("Set STAGING_SEED_PASSWORD", file=sys.stderr)
        sys.exit(1)
    email_domain = os.environ.get("SEED_EMAIL_DOMAIN", "prelura.com")
    graphql_url = args.graphql_url.rstrip("/") + "/"

    rng = random.Random(args.seed if args.seed is not None else random.randrange(1 << 31))

    males = mod.load_usernames(args.male_list)
    females = mod.load_usernames(args.female_list)
    all_likers = list(dict.fromkeys(males + females))
    if len(all_likers) < 2:
        print("Need at least 2 seed usernames.", file=sys.stderr)
        sys.exit(1)

    probe = all_likers[0]
    probe_tok = mod.login(graphql_url, password, probe, email_domain)
    posts = fetch_all_posts_with_comment_count(
        graphql_url,
        probe_tok,
        mod.graphql_json,
        page_size=args.page_size,
        max_posts=args.max_posts,
        single_cap=getattr(mod, "LOOKBOOKS_SINGLE_REQUEST_CAP", 50_000),
    )
    print(f"Fetched {len(posts)} lookbook post(s).")

    comments_flat: list[dict[str, Any]] = []
    for p in posts:
        pid = p["id"]
        cc = p.get("commentsCount")
        if cc is not None and cc <= 0:
            continue
        try:
            rows = fetch_comments_for_post(graphql_url, probe_tok, pid, mod.graphql_json)
        except Exception as e:
            print(f"warn: comments for post {pid}: {e}", file=sys.stderr)
            continue
        for c in rows:
            comments_flat.append(c)

    print(f"Collected {len(comments_flat)} comment(s).")

    # Target likes per comment + liker assignments
    edges: list[tuple[str, str, str]] = []
    stats_targets: dict[int, int] = {}
    skipped_at_cap = 0
    skipped_already_enough = 0

    for c in comments_flat:
        cid = c["id"]
        post_id = c["postId"]
        author = (c.get("username") or "").strip()
        current = int(c.get("likesCount") or 0)
        if current >= 5:
            skipped_at_cap += 1
            continue

        target = sample_target_likes(rng)
        target = min(target, 5)
        stats_targets[target] = stats_targets.get(target, 0) + 1
        need = max(0, target - current)
        if need <= 0:
            skipped_already_enough += 1
            continue

        pool = [u for u in all_likers if u.lower() != author.lower()]
        if len(pool) < need:
            need = len(pool)
        if need <= 0:
            continue
        chosen = rng.sample(pool, need)
        for liker in chosen:
            edges.append((liker, cid, post_id))

    plan_fp = plan_fingerprint(edges)
    out_plan = {
        "comments_total": len(comments_flat),
        "target_histogram_requested": stats_targets,
        "skipped_comment_likes_already_5": skipped_at_cap,
        "skipped_already_at_target": skipped_already_enough,
        "like_edges_planned": len(edges),
        "distribution_note": "per-comment target totals: 10%→5, 15%→4, 10%→3, 30%→2, 35%→1 (then skip if already enough likes)",
    }
    print(json.dumps(out_plan, indent=2))

    if args.dry_run:
        SUMMARY_PATH.parent.mkdir(parents=True, exist_ok=True)
        SUMMARY_PATH.write_text(
            json.dumps({"dry_run": True, "plan": out_plan, "plan_fingerprint": plan_fp}, indent=2),
            encoding="utf-8",
        )
        print(f"Wrote {SUMMARY_PATH}")
        return

    sleep_s = max(0.0, args.sleep_ms / 1000.0)
    checkpoint_path: Path | None = None if args.no_checkpoint else args.checkpoint
    completed: set[str] = set()
    if checkpoint_path:
        fp, done = load_checkpoint(checkpoint_path)
        if fp == plan_fp:
            completed = done
        elif fp:
            print("Checkpoint ignored (plan changed).", file=sys.stderr)

    # Group edges by (liker, post_id) to batch-fetch comments once per group
    by_liker_post: dict[tuple[str, str], list[str]] = defaultdict(list)
    for liker, cid, pid in edges:
        by_liker_post[(liker, pid)].append(cid)

    applied = 0
    skipped_already = 0
    errors: list[dict[str, Any]] = []
    token_cache: dict[str, str] = {}

    ordered_groups = sorted(by_liker_post.keys(), key=lambda x: (x[0], x[1]))

    for (liker, post_id) in ordered_groups:
        comment_ids = by_liker_post[(liker, post_id)]
        if liker not in token_cache:
            try:
                token_cache[liker] = mod.login(graphql_url, password, liker, email_domain)
            except Exception as e:
                for cid in comment_ids:
                    errors.append({"liker": liker, "commentId": cid, "phase": "login", "error": str(e)})
                continue
        tok = token_cache[liker]

        if sleep_s:
            time.sleep(sleep_s)
        try:
            rows = fetch_comments_for_post(graphql_url, tok, post_id, mod.graphql_json)
        except Exception as e:
            for cid in comment_ids:
                errors.append({"liker": liker, "commentId": cid, "phase": "fetchComments", "error": str(e)})
            continue

        by_id = {r["id"]: r for r in rows}

        for cid in comment_ids:
            ek = edge_key(liker, cid)
            if ek in completed:
                continue
            row = by_id.get(cid)
            if row is None:
                errors.append({"liker": liker, "commentId": cid, "phase": "lookup", "error": "comment not in fetch"})
                continue
            if bool(row.get("userLiked")):
                skipped_already += 1
                completed.add(ek)
                if checkpoint_path:
                    save_checkpoint(checkpoint_path, plan_fp, completed)
                continue
            if sleep_s:
                time.sleep(sleep_s)
            ok, err = toggle_comment_like(graphql_url, tok, cid, mod.graphql_json)
            if ok:
                applied += 1
                completed.add(ek)
                if checkpoint_path:
                    save_checkpoint(checkpoint_path, plan_fp, completed)
            else:
                errors.append({"liker": liker, "commentId": cid, "phase": "toggle", "error": err})

    summary = {
        "plan": out_plan,
        "likes_applied": applied,
        "skipped_already_liked": skipped_already,
        "errors": errors[:200],
        "error_count": len(errors),
        "plan_fingerprint": plan_fp,
        "checkpoint_edges": len(completed),
    }
    SUMMARY_PATH.parent.mkdir(parents=True, exist_ok=True)
    SUMMARY_PATH.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(json.dumps({k: summary[k] for k in ("likes_applied", "skipped_already_liked", "error_count")}, indent=2))
    print(f"Summary: {SUMMARY_PATH}")
    if errors:
        sys.exit(1)


if __name__ == "__main__":
    main()
