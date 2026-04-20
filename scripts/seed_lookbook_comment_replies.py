#!/usr/bin/env python3
"""
Post authors from the seed username lists **reply** to **other people's** lookbook comments on
their own posts via ``addLookbookComment`` with ``parentCommentId`` set.

  • Only posts whose ``username`` is in the merged male + female seed lists are considered.
  • Eligible comments: author ≠ post author (someone else commented on the poster's lookbook).
  • By default **~50%** of eligible comments receive one reply (Bernoulli per comment; see
    ``--reply-ratio``). Re-run with the same ``SEED_RANDOM_SEED`` for a stable plan.
  • Reply text is chosen from a large template pool and **bucketed** from the original comment
    (question vs hype vs commerce vs general). Most picks match tone; a minority are slightly
    more generic so it is not robotic.

Requires ``STAGING_SEED_PASSWORD``. Optional: ``GRAPHQL_URL``, ``SEED_EMAIL_DOMAIN``,
``SEED_RANDOM_SEED``.

  STAGING_SEED_PASSWORD='…' python3 scripts/seed_lookbook_comment_replies.py --dry-run
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
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_MALE_LIST = SCRIPT_DIR / "data" / "seed-usernames-male.txt"
DEFAULT_FEMALE_LIST = SCRIPT_DIR / "data" / "seed-usernames-female.txt"
DEFAULT_CHECKPOINT = SCRIPT_DIR / "data" / "lookbook_comment_replies_checkpoint.json"
SUMMARY_PATH = SCRIPT_DIR / "data" / "lookbook_comment_replies_summary.json"
CHECKPOINT_VERSION = 1

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
    text
    parentCommentId
    likesCount
  }
}"""

ADD_REPLY = """mutation AddLookbookComment($postId: UUID!, $text: String!, $parentCommentId: UUID) {
  addLookbookComment(postId: $postId, text: $text, parentCommentId: $parentCommentId) {
    success
    message
    commentsCount
    comment { id username text }
  }
}"""


def graphql_uuid(raw: str) -> str:
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


def _load_seed_lookbook_likes():
    path = SCRIPT_DIR / "seed_lookbook_likes.py"
    spec = importlib.util.spec_from_file_location("seed_lookbook_likes", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Cannot load {path}")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def comment_bucket(text: str) -> str:
    t = (text or "").strip().lower()
    if not t:
        return "general"
    if "?" in text or any(w in t for w in ("how ", "what ", "where ", "when ", "why ", "which ", "can you", "could you", "do you")):
        return "question"
    if any(x in t for x in ("price", "ship", "postage", "buy", "sell", "still available", "size ", "link", "dm")):
        return "commerce"
    if any(x in t for x in ("love", "obsessed", "stunning", "gorgeous", "beautiful", "fire", "🔥", "❤", "😍", "amazing", "incredible", "goals")):
        return "hype"
    if any(x in t for x in ("lol", "haha", "funny", "😂", "dead", "stop")):
        return "playful"
    return "general"


# Large pool so consecutive replies rarely repeat verbatim; buckets tuned for marketplace / fashion tone.
REPLIES: dict[str, list[str]] = {
    "question": [
        "Honestly mostly second-hand finds — happy to share more detail if you want!",
        "Good question — mix of thrift + a couple of newer staples.",
        "It’s a bit of a mashup tbh, mostly pieced together over time.",
        "Depends on the day — I rotate a few favourites.",
        "Nothing too fancy, just stuff I actually wear on repeat.",
        "A little bit of hunting, a little bit of luck.",
        "I try to keep it simple — layers help.",
        "Still figuring it out myself, but I’m glad it reads well on camera.",
    ],
    "hype": [
        "Thank you so much, that means a lot.",
        "Appreciate you saying that — made my day.",
        "You’re way too kind, thank you.",
        "Thank you! Really glad you like the vibe.",
        "That’s so nice of you, thank you.",
        "Means a lot, thank you for the love.",
        "Thank you — always nice to hear.",
        "Haha thank you, I’ll take the hype.",
    ],
    "commerce": [
        "Thanks for asking — I’ll keep an eye on messages for you.",
        "Appreciate the interest! I’ll follow up when I can.",
        "Thanks — best to check listings / messages for the details.",
        "Good shout — I’ll try to get back to you soon.",
        "Thanks! I’ll reply properly when I’m at my desk.",
        "Appreciate it — I’m a bit slow on replies sometimes but I’ll get there.",
    ],
    "playful": [
        "Haha thank you — I’ll allow it.",
        "Okay okay I’ll take that energy.",
        "Stop you’re gonna make me smile at my phone.",
        "Haha love that, thank you.",
        "That comment wins today.",
    ],
    "general": [
        "Thank you!",
        "Thanks for stopping by the post.",
        "Appreciate you taking a look.",
        "Thanks for the comment.",
        "Means a lot, thank you.",
        "Glad this one landed — thank you.",
        "Thank you for the kind words.",
        "Always nice to hear — thanks.",
        "Thanks — hope you’re having a good week too.",
        "Thank you, really appreciate it.",
        "Thanks for engaging with the post.",
        "Appreciate the support, thank you.",
        "Thank you for saying hi in the comments.",
        "Thanks! Hope you find something you love on here too.",
    ],
}

# Slightly off-bucket lines (used ~15% of the time) so tone is not 100% “perfect match”.
GENERIC_EXTRAS: list[str] = [
    "Thanks for commenting!",
    "Appreciate you!",
    "Thank you — more coming soon.",
    "Thanks, means a lot.",
    "Really appreciate you taking the time.",
]


def pick_reply_text(rng: random.Random, original: str) -> str:
    b = comment_bucket(original)
    if rng.random() < 0.15:
        base = rng.choice(GENERIC_EXTRAS)
    else:
        pool = REPLIES.get(b, REPLIES["general"])
        base = rng.choice(pool)
    # Light uniqueness: optional trailing fragment (not every time).
    if rng.random() < 0.22:
        suffixes = [" 🙏", " ✨", " — thank you again", ""]
        base = base.rstrip() + rng.choice(suffixes)
    return base.strip()


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
            {"query": LOOKBOOKS_PAGED_COUNT, "variables": variables, "operationName": "LookbooksFeed"},
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
        if not (pi.get("hasNextPage") is True and (pi.get("endCursor") or "").strip()):
            return merged
        cursor = (pi.get("endCursor") or "").strip()

    if merged:
        return merged

    first_cap = min(max(1, max_posts), single_cap)
    r = graphql_json(
        graphql_url,
        {"query": LOOKBOOKS_WITH_COUNT, "variables": {"first": first_cap}, "operationName": "Lookbooks"},
        token=token,
    )
    if r.get("errors"):
        raise RuntimeError(json.dumps(r["errors"]))
    conn = (r.get("data") or {}).get("lookbooks") or {}
    _extend_posts_count(conn, merged, seen, max_posts)
    return merged


def fetch_comments(graphql_url: str, token: str, post_id: str, graphql_json) -> list[dict[str, Any]]:
    normalized = graphql_uuid(post_id)
    r = graphql_json(
        graphql_url,
        {"query": LOOKBOOK_COMMENTS, "variables": {"postId": normalized}, "operationName": "LookbookComments"},
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
        out.append(
            {
                "id": cid,
                "username": str(row.get("username") or "").strip(),
                "text": str(row.get("text") or ""),
                "parentCommentId": row.get("parentCommentId"),
            }
        )
    return out


def add_reply(
    graphql_url: str,
    token: str,
    post_id: str,
    text: str,
    parent_comment_id: str,
    graphql_json,
) -> dict[str, Any]:
    variables: dict[str, Any] = {
        "postId": graphql_uuid(post_id),
        "text": text,
        "parentCommentId": graphql_uuid(parent_comment_id),
    }
    return graphql_json(
        graphql_url,
        {"query": ADD_REPLY, "variables": variables, "operationName": "AddLookbookComment"},
        token=token,
    )


def plan_fingerprint(items: list[tuple[str, str]]) -> str:
    """(post_id, comment_id) sorted"""
    s = json.dumps(sorted([list(x) for x in items]), separators=(",", ":"))
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
    done = raw.get("replied_to_comment_ids") or []
    if not isinstance(done, list):
        return None, set()
    return fp, {str(x) for x in done}


def save_checkpoint(path: Path, plan_fp: str, done: set[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(
        json.dumps(
            {"version": CHECKPOINT_VERSION, "plan_fingerprint": plan_fp, "replied_to_comment_ids": sorted(done)},
            separators=(",", ":"),
        ),
        encoding="utf-8",
    )
    tmp.replace(path)


def main() -> None:
    mod = _load_seed_lookbook_likes()

    parser = argparse.ArgumentParser(description="Seed lookbook comment replies from post authors.")
    parser.add_argument("--graphql-url", default=os.environ.get("GRAPHQL_URL", mod.DEFAULT_GRAPHQL))
    parser.add_argument("--male-list", type=Path, default=DEFAULT_MALE_LIST)
    parser.add_argument("--female-list", type=Path, default=DEFAULT_FEMALE_LIST)
    parser.add_argument("--max-posts", type=int, default=50_000)
    parser.add_argument("--page-size", type=int, default=100)
    parser.add_argument("--reply-ratio", type=float, default=0.5, help="Fraction of eligible comments to reply to (~Bernoulli).")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--sleep-ms", type=int, default=60)
    parser.add_argument("--checkpoint", type=Path, default=DEFAULT_CHECKPOINT)
    parser.add_argument("--no-checkpoint", action="store_true")
    parser.add_argument("--seed", type=int, default=None)
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
    seed_users = {u.lower() for u in dict.fromkeys(males + females)}
    if len(seed_users) < 1:
        print("Need seed usernames.", file=sys.stderr)
        sys.exit(1)

    probe = males[0] if males else females[0]
    probe_tok = mod.login(graphql_url, password, probe, email_domain)
    posts = fetch_all_posts_with_comment_count(
        graphql_url,
        probe_tok,
        mod.graphql_json,
        page_size=args.page_size,
        max_posts=args.max_posts,
        single_cap=getattr(mod, "LOOKBOOKS_SINGLE_REQUEST_CAP", 50_000),
    )

    ours = [p for p in posts if (p.get("username") or "").strip().lower() in seed_users]
    print(f"Posts from seed authors: {len(ours)} (of {len(posts)} fetched).")

    # Build eligible (post_id, poster, comment_id, comment_text)
    eligible: list[dict[str, Any]] = []
    for p in ours:
        pid = p["id"]
        poster = (p.get("username") or "").strip()
        cc = p.get("commentsCount")
        if cc is not None and cc <= 0:
            continue
        try:
            comments = fetch_comments(graphql_url, probe_tok, pid, mod.graphql_json)
        except Exception as e:
            print(f"warn: comments {pid}: {e}", file=sys.stderr)
            continue
        for c in comments:
            author = (c.get("username") or "").strip()
            if author.lower() == poster.lower():
                continue
            txt = (c.get("text") or "").strip()
            if not txt:
                continue
            eligible.append(
                {
                    "post_id": pid,
                    "poster": poster,
                    "comment_id": c["id"],
                    "comment_text": txt,
                }
            )

    # ~50% of eligible comments (Bernoulli)
    selected: list[dict[str, Any]] = []
    for row in eligible:
        if rng.random() < args.reply_ratio:
            selected.append(row)

    # Unique reply text per row (re-pick if collision with same text on another row — rare)
    work: list[dict[str, Any]] = []
    seen_texts: set[str] = set()
    for row in selected:
        t0 = pick_reply_text(rng, row["comment_text"])
        guard = 0
        while t0 in seen_texts and guard < 40:
            t0 = pick_reply_text(rng, row["comment_text"])
            guard += 1
        seen_texts.add(t0)
        work.append({**row, "reply_text": t0})

    plan_keys = [(x["post_id"], x["comment_id"]) for x in work]
    fp = plan_fingerprint(plan_keys)

    meta = {
        "eligible_comments": len(eligible),
        "selected_for_reply": len(work),
        "reply_ratio": args.reply_ratio,
        "seed_posts_scanned": len(ours),
    }
    print(json.dumps(meta, indent=2))

    if args.dry_run:
        SUMMARY_PATH.parent.mkdir(parents=True, exist_ok=True)
        SUMMARY_PATH.write_text(
            json.dumps({"dry_run": True, "meta": meta, "sample": work[:25], "plan_fingerprint": fp}, indent=2),
            encoding="utf-8",
        )
        print(f"Wrote {SUMMARY_PATH}")
        return

    checkpoint_path: Path | None = None if args.no_checkpoint else args.checkpoint
    done_ids: set[str] = set()
    if checkpoint_path:
        loaded_fp, loaded = load_checkpoint(checkpoint_path)
        if loaded_fp == fp:
            done_ids = loaded
        elif loaded_fp:
            print("Checkpoint ignored (plan changed).", file=sys.stderr)

    sleep_s = max(0.0, args.sleep_ms / 1000.0)
    token_cache: dict[str, str] = {}
    ok = 0
    errors: list[dict[str, Any]] = []

    for row in work:
        cid = row["comment_id"]
        if cid in done_ids:
            continue
        poster = row["poster"]
        if poster not in token_cache:
            try:
                token_cache[poster] = mod.login(graphql_url, password, poster, email_domain)
            except Exception as e:
                errors.append({"poster": poster, "commentId": cid, "phase": "login", "error": str(e)})
                continue
        tok = token_cache[poster]
        if sleep_s:
            time.sleep(sleep_s)
        r = add_reply(graphql_url, tok, row["post_id"], row["reply_text"], cid, mod.graphql_json)
        if r.get("errors"):
            errors.append({"commentId": cid, "error": json.dumps(r["errors"])})
            continue
        pl = (r.get("data") or {}).get("addLookbookComment") or {}
        if pl.get("success") is not True:
            errors.append({"commentId": cid, "message": pl.get("message"), "raw": str(r)[:600]})
            continue
        ok += 1
        done_ids.add(cid)
        if checkpoint_path:
            save_checkpoint(checkpoint_path, fp, done_ids)

    summary = {
        "meta": meta,
        "replies_posted": ok,
        "errors": errors[:100],
        "error_count": len(errors),
        "plan_fingerprint": fp,
    }
    SUMMARY_PATH.parent.mkdir(parents=True, exist_ok=True)
    SUMMARY_PATH.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(json.dumps({"replies_posted": ok, "error_count": len(errors), "summary": str(SUMMARY_PATH)}, indent=2))
    if errors:
        sys.exit(1)


if __name__ == "__main__":
    main()
