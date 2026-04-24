#!/usr/bin/env python3
"""
Sum ``likesCount`` across lookbook posts from the ``lookbooks`` GraphQL connection.

By default fetches **as many posts as the API allows** (paginated when ``pageInfo`` exists,
otherwise one large ``first`` request).

  STAGING_SEED_PASSWORD='…' python3 scripts/sum_lookbook_feed_likes.py

This is **total likes on those posts** (organic + seeded), not “seed script only.”

Limit with ``--max-posts`` for testing.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))
from seed_lookbook_likes import (  # noqa: E402
    DEFAULT_FEMALE_LIST,
    DEFAULT_GRAPHQL,
    DEFAULT_MALE_LIST,
    LOOKBOOKS_SINGLE_REQUEST_CAP,
    graphql_json,
    load_usernames,
    login,
)

LOOKBOOKS_LIKES_SIMPLE = """query LookbooksLikes($first: Int) {
  lookbooks(first: $first) {
    nodes { id likesCount }
    edges { node { id likesCount } }
  }
}"""

LOOKBOOKS_LIKES_PAGED = """query LookbooksLikesFeed($first: Int, $after: String) {
  lookbooks(first: $first, after: $after) {
    pageInfo { hasNextPage endCursor }
    nodes { id likesCount }
    edges { node { id likesCount } }
  }
}"""


def _rows_from_conn(conn: dict[str, Any]) -> list[dict[str, Any]]:
    batch: list[dict[str, Any]] = []
    if conn.get("nodes"):
        batch = [x for x in conn["nodes"] if x]
    elif conn.get("edges"):
        batch = [e["node"] for e in conn["edges"] if e and e.get("node")]
    return batch


def _ingest_rows(rows: list[dict[str, Any]], by_id: dict[str, int]) -> None:
    for row in rows:
        pid = str(row.get("id") or "").strip()
        if not pid:
            continue
        lc = row.get("likesCount")
        by_id[pid] = int(lc) if lc is not None else 0


def fetch_all_likes_by_post(
    graphql_url: str,
    token: str,
    *,
    page_size: int,
    max_posts: int,
) -> tuple[dict[str, int], str]:
    """
    Returns (post_id -> likesCount, mode_description).
    """
    by_id: dict[str, int] = {}

    # 1) Paginated path (full Relay connection).
    cursor: str | None = None
    iterations = 0
    while len(by_id) < max_posts and iterations < 500:
        iterations += 1
        take = min(page_size, max(1, max_posts - len(by_id)))
        variables: dict[str, Any] = {"first": take, "after": cursor}
        r = graphql_json(
            graphql_url,
            {
                "query": LOOKBOOKS_LIKES_PAGED,
                "variables": variables,
                "operationName": "LookbooksLikesFeed",
            },
            token=token,
        )
        if r.get("errors"):
            err_txt = json.dumps(r["errors"]).lower()
            if "pageinfo" in err_txt or "cannot query field" in err_txt:
                break
            print(json.dumps(r["errors"], indent=2), file=sys.stderr)
            sys.exit(1)

        conn = (r.get("data") or {}).get("lookbooks") or {}
        rows = _rows_from_conn(conn)
        if not rows:
            return by_id, "paginated"

        _ingest_rows(rows, by_id)
        if len(by_id) >= max_posts:
            return by_id, "paginated (stopped at --max-posts)"
        pi = conn.get("pageInfo") or {}
        has_next = pi.get("hasNextPage") is True
        end = (pi.get("endCursor") or "").strip()
        if not has_next or not end:
            return by_id, "paginated"
        cursor = end

    # Paged path ran but did not return (e.g. iteration cap); do not duplicate-fetch via simple.
    if by_id:
        return by_id, "paginated (stopped: iteration or size cap)"

    # 2) Single-page path (no pageInfo on connection - staging).
    first_cap = min(max(1, max_posts), LOOKBOOKS_SINGLE_REQUEST_CAP)
    r = graphql_json(
        graphql_url,
        {
            "query": LOOKBOOKS_LIKES_SIMPLE,
            "variables": {"first": first_cap},
            "operationName": "LookbooksLikes",
        },
        token=token,
    )
    if r.get("errors"):
        print(json.dumps(r["errors"], indent=2), file=sys.stderr)
        sys.exit(1)

    conn = (r.get("data") or {}).get("lookbooks") or {}
    rows = _rows_from_conn(conn)
    _ingest_rows(rows, by_id)
    if first_cap >= len(rows):
        return by_id, f"single request (first={first_cap}; likely full set if server capped lower)"
    return by_id, f"single request (first={first_cap}; got {len(rows)} rows - server may cap)"


def main() -> None:
    parser = argparse.ArgumentParser(description="Sum likesCount on lookbook feed posts (GraphQL).")
    parser.add_argument("--graphql-url", default=os.environ.get("GRAPHQL_URL", DEFAULT_GRAPHQL))
    parser.add_argument("--male-list", type=Path, default=DEFAULT_MALE_LIST)
    parser.add_argument("--female-list", type=Path, default=DEFAULT_FEMALE_LIST)
    parser.add_argument(
        "--page-size",
        type=int,
        default=100,
        help="Page size when the API supports cursor pagination.",
    )
    parser.add_argument(
        "--max-posts",
        type=int,
        default=1_000_000,
        metavar="N",
        help="Safety cap on how many posts to fetch (default: very large).",
    )
    parser.add_argument(
        "--first",
        type=int,
        default=None,
        metavar="N",
        help="Legacy: only sum the first N posts (one request). Overrides full fetch.",
    )
    args = parser.parse_args()

    password = os.environ.get("STAGING_SEED_PASSWORD")
    if not password:
        print("Set STAGING_SEED_PASSWORD", file=sys.stderr)
        sys.exit(1)
    email_domain = os.environ.get("SEED_EMAIL_DOMAIN", "prelura.com")
    graphql_url = args.graphql_url.rstrip("/") + "/"

    males = load_usernames(args.male_list)
    females = load_usernames(args.female_list)
    all_users = list(dict.fromkeys(males + females))
    if not all_users:
        sys.exit("No usernames in lists.")

    tok = login(graphql_url, password, all_users[0], email_domain)

    if args.first is not None:
        r = graphql_json(
            graphql_url,
            {
                "query": LOOKBOOKS_LIKES_SIMPLE,
                "variables": {"first": max(1, args.first)},
                "operationName": "LookbooksLikes",
            },
            token=tok,
        )
        if r.get("errors"):
            print(json.dumps(r["errors"], indent=2), file=sys.stderr)
            sys.exit(1)
        conn = (r.get("data") or {}).get("lookbooks") or {}
        rows = _rows_from_conn(conn)
        by_id: dict[str, int] = {}
        _ingest_rows(rows, by_id)
        mode = f"single page (--first {args.first})"
    else:
        by_id, mode = fetch_all_likes_by_post(
            graphql_url,
            tok,
            page_size=max(1, args.page_size),
            max_posts=max(1, args.max_posts),
        )

    total = sum(by_id.values())
    n = len(by_id)

    print(f"Fetch mode: {mode}")
    print(f"Posts counted: {n} (unique ids)")
    print(f"Sum of likesCount on those posts: {total}")
    print(
        "(Not 'seed script only' - every like the API reports on those posts.)",
        file=sys.stderr,
    )


if __name__ == "__main__":
    main()
