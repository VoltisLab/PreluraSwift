#!/usr/bin/env python3
"""
Distribute a **fixed total** of lookbook likes across **all** posts on the platform, using only
accounts from a dedicated liker list (e.g. the “unknown” seed usernames file).

  • Fetches every lookbook post (same pagination strategy as ``seed_lookbook_likes.py``).
  • Builds per-post targets whose **sum equals** ``--total-likes`` (default **2000**), with
    **no post above** ``--max-per-post`` (default **33**).
  • Only a **small fraction** of posts are even *allowed* to reach the max (default **1.5%**);
    everyone else is capped at **max−1** so hitting 33 stays rare.
  • Skewed weights give most posts a few likes and a long tail of lower counts; only a tiny
    share of the “eligible” posts actually land on the max after rounding.

  Required env: ``STAGING_SEED_PASSWORD``. Optional: ``GRAPHQL_URL``, ``SEED_EMAIL_DOMAIN``,
  ``SEED_RANDOM_SEED``.

  Example::

    STAGING_SEED_PASSWORD='…' python3 scripts/seed_lookbook_likes_unknown_budget.py \\
      --liker-list /Users/user/Downloads/seed-usernames-unknown.txt

  Dry run::

    STAGING_SEED_PASSWORD='…' python3 scripts/seed_lookbook_likes_unknown_budget.py --dry-run
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import math
import os
import random
import sys
import time
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_LIKER_LIST = Path.home() / "Downloads" / "seed-usernames-unknown.txt"
DEFAULT_TOTAL_LIKES = 2000
DEFAULT_MAX_PER_POST = 33
DEFAULT_PCT_CAN_REACH_MAX = 0.015  # 1.5% of posts may use the top slot (33 vs 32)
CHECKPOINT_VERSION = 2
DEFAULT_CHECKPOINT = SCRIPT_DIR / "data" / "lookbook_likes_unknown_budget_checkpoint.json"
SUMMARY_PATH = SCRIPT_DIR / "data" / "lookbook_likes_unknown_budget_summary.json"
LAST_RANDOM_SEED_FILE = SCRIPT_DIR / "data" / "lookbook_likes_unknown_budget_last_seed.txt"


def _load_seed_lookbook_likes_module():
    path = SCRIPT_DIR / "seed_lookbook_likes.py"
    spec = importlib.util.spec_from_file_location("seed_lookbook_likes", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Cannot load {path}")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def allocate_skewed_integer_budget(
    n: int,
    budget: int,
    caps: list[int],
    rng: random.Random,
    *,
    skew_power: float = 3.0,
) -> tuple[list[int], int]:
    """
    Non-negative integers t[i] with sum t == budget (if feasible), each t[i] <= caps[i].
    Uses **lognormal** weights (many tiny, a long tail toward higher counts) so a few posts
    can approach the per-post cap while most stay low. ``skew_power`` scales the normal
    draw before exp (higher → slightly more mass at the bottom).
    """
    if n <= 0:
        return [], budget
    if budget <= 0:
        return [0] * n, 0
    cap_sum = sum(caps)
    if budget > cap_sum:
        return [caps[i] for i in range(n)], budget - cap_sum

    # Lognormal: occasional large weights → a small set of posts can reach high targets (≤ cap).
    sigma = 1.15 + min(0.35, skew_power * 0.08)
    mu = -1.35 - skew_power * 0.12
    weights = [math.exp(rng.normalvariate(mu, sigma)) for _ in range(n)]
    s = sum(weights) or 1.0
    ideal = [budget * weights[i] / s for i in range(n)]
    t = [min(caps[i], int(ideal[i])) for i in range(n)]
    rem = budget - sum(t)
    # Largest remainder: give +1 to posts with highest fractional part, respecting caps.
    fracs = sorted(range(n), key=lambda i: ideal[i] - int(ideal[i]), reverse=True)
    for i in fracs:
        if rem <= 0:
            break
        if t[i] < caps[i]:
            t[i] += 1
            rem -= 1
    # Any leftover (everyone fractional-pass hit cap): round-robin slack.
    idx = 0
    safety = 0
    max_safety = n * max(budget, cap_sum) + n * 20
    while rem > 0 and safety < max_safety:
        i = idx % n
        idx += 1
        safety += 1
        if t[i] < caps[i]:
            t[i] += 1
            rem -= 1
    return t, rem


def build_budget_like_plan(
    posts: list[dict[str, str]],
    likers: list[str],
    rng: random.Random,
    *,
    total_likes: int,
    max_per_post: int,
    pct_can_reach_max: float,
    skew_power: float = 3.0,
) -> tuple[dict[str, list[str]], dict[str, Any]]:
    """
    liker_username -> [post_id, ...]  (distinct posts per liker; distinct likers per post).
    """
    from collections import defaultdict

    user_lower = {u.lower(): u for u in likers}
    n = len(posts)
    if n == 0:
        return {}, {"error": "no posts", "posts_total": 0, "total_like_edges": 0}

    k_eligible = max(0, min(n, int(round(n * pct_can_reach_max))))
    if k_eligible == 0 and max_per_post > 1 and n > 0:
        k_eligible = 1
    eligible = set(rng.sample(range(n), k_eligible)) if k_eligible > 0 else set()

    caps = [max_per_post if i in eligible else max(0, max_per_post - 1) for i in range(n)]
    cap_sum = sum(caps)
    budget = min(total_likes, cap_sum)
    shortfall_global = total_likes - budget if total_likes > cap_sum else 0

    targets, rem_unplaced = allocate_skewed_integer_budget(n, budget, caps, rng, skew_power=skew_power)

    liker_to_posts: dict[str, list[str]] = defaultdict(list)
    skipped_pool = 0
    reduced_edges = 0

    for idx, post in enumerate(posts):
        pid = post["id"]
        poster = (post.get("username") or "").strip()
        poster_l = poster.lower()
        pool = [user_lower[k] for k in user_lower if k != poster_l]
        want = targets[idx]
        if want == 0:
            continue
        take = min(want, len(pool))
        if take < want:
            reduced_edges += want - take
        if take == 0:
            skipped_pool += 1
            continue
        chosen = rng.sample(pool, take)
        for liker in chosen:
            liker_to_posts[liker].append(pid)

    at_max = sum(1 for v in targets if v == max_per_post)
    stats: dict[str, Any] = {
        "posts_total": n,
        "likers_in_list": len(likers),
        "total_likes_requested": total_likes,
        "budget_after_global_cap": budget,
        "global_capacity": cap_sum,
        "shortfall_total_over_capacity": shortfall_global,
        "max_per_post": max_per_post,
        "pct_can_reach_max": pct_can_reach_max,
        "posts_eligible_for_max_slot": k_eligible,
        "posts_at_exactly_max": at_max,
        "target_histogram_top": {
            str(k): sum(1 for v in targets if v == k)
            for k in sorted(set(targets), reverse=True)[:12]
        },
        "total_like_edges": sum(len(v) for v in liker_to_posts.values()),
        "skipped_no_liker_pool": skipped_pool,
        "edges_reduced_insufficient_pool": reduced_edges,
        "allocator_remainder_unplaced": rem_unplaced,
    }
    return dict(liker_to_posts), stats


def plan_fingerprint(liker_to_posts: dict[str, list[str]]) -> str:
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


def edge_key(liker: str, post_id: str) -> str:
    return f"{liker}\t{post_id}"


def resolve_rng_seed(
    *,
    env_value: str | None,
    reuse_saved: bool,
    last_seed_path: Path,
) -> tuple[random.Random, int, str]:
    import secrets

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
    return random.Random(s), s, f"generated (saved to {last_seed_path.name})"


def main() -> None:
    mod = _load_seed_lookbook_likes_module()

    parser = argparse.ArgumentParser(
        description="Seed a fixed total of lookbook likes using only the unknown liker list."
    )
    parser.add_argument(
        "--liker-list",
        type=Path,
        default=DEFAULT_LIKER_LIST,
        help=f"One username per line (default: {DEFAULT_LIKER_LIST})",
    )
    parser.add_argument("--graphql-url", default=os.environ.get("GRAPHQL_URL", mod.DEFAULT_GRAPHQL))
    parser.add_argument("--total-likes", type=int, default=DEFAULT_TOTAL_LIKES)
    parser.add_argument("--max-per-post", type=int, default=DEFAULT_MAX_PER_POST)
    parser.add_argument(
        "--pct-can-reach-max",
        type=float,
        default=DEFAULT_PCT_CAN_REACH_MAX,
        help="Fraction of posts allowed to use the top count (e.g. 33); others cap at max-1.",
    )
    parser.add_argument(
        "--skew-power",
        type=float,
        default=3.0,
        help="Tail tuning for the lognormal like allocation (higher → more posts stay very low). Default: 3.",
    )
    parser.add_argument("--max-posts", type=int, default=50_000)
    parser.add_argument("--page-size", type=int, default=100)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--sleep-ms", type=int, default=0)
    parser.add_argument("--progress-every", type=int, default=1)
    parser.add_argument("--checkpoint", type=Path, default=DEFAULT_CHECKPOINT)
    parser.add_argument("--no-checkpoint", action="store_true")
    parser.add_argument("--reuse-saved-seed", action="store_true")
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

    likers = mod.load_usernames(args.liker_list)
    if len(likers) < 2:
        print("Need at least 2 usernames in --liker-list.", file=sys.stderr)
        sys.exit(1)

    probe_tok = mod.login(graphql_url, password, likers[0], email_domain)
    posts = mod.fetch_all_lookbook_posts(
        graphql_url, probe_tok, page_size=args.page_size, max_posts=args.max_posts
    )
    print(f"Fetched {len(posts)} lookbook post(s).")

    liker_to_posts, stats = build_budget_like_plan(
        posts,
        likers,
        rng,
        total_likes=args.total_likes,
        max_per_post=args.max_per_post,
        pct_can_reach_max=args.pct_can_reach_max,
        skew_power=args.skew_power,
    )
    print("Plan stats:", json.dumps(stats, indent=2))

    if stats.get("shortfall_total_over_capacity", 0) > 0:
        print(
            f"Warning: platform capacity (sum of per-post caps) is below --total-likes; "
            f"using {stats.get('budget_after_global_cap')} likes.",
            file=sys.stderr,
        )

    SUMMARY_PATH.parent.mkdir(parents=True, exist_ok=True)
    if args.dry_run:
        SUMMARY_PATH.write_text(
            json.dumps(
                {
                    "dry_run": True,
                    "stats": stats,
                    "graphql_url": graphql_url,
                    "random_seed": resolved_seed,
                    "liker_list": str(args.liker_list),
                },
                indent=2,
            ),
            encoding="utf-8",
        )
        print(f"Wrote {SUMMARY_PATH}")
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
                "Checkpoint ignored: plan fingerprint does not match this run.\n"
            )
            sys.stderr.flush()

    if total_edges > 0:
        sys.stderr.write("Applying likes (progress on stderr)…\n")
        if checkpoint_path and completed_keys:
            sys.stderr.write(
                f"Resuming: {len(completed_keys)}/{total_edges} edges already done.\n"
            )
        sys.stderr.flush()

    for liker in sorted(liker_to_posts.keys()):
        post_ids = liker_to_posts[liker]
        pending = [pid for pid in post_ids if edge_key(liker, pid) not in completed_keys]
        if not pending:
            scan += len(post_ids)
            continue
        try:
            tok = mod.login(graphql_url, password, liker, email_domain)
        except Exception as e:
            errors.append({"liker": liker, "phase": "login", "error": str(e)})
            scan += len(post_ids)
            continue

        for pid in post_ids:
            scan += 1
            key = edge_key(liker, pid)
            if key in completed_keys:
                mod._report_like_progress(
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
            ul = mod.lookbook_user_liked(graphql_url, tok, pid)
            if ul is True:
                skipped_already += 1
                completed_keys.add(key)
                if checkpoint_path:
                    save_checkpoint(checkpoint_path, plan_fp, completed_keys)
            elif ul is None:
                errors.append({"liker": liker, "postId": pid, "phase": "lookbookPost", "error": "missing or error"})
            else:
                ok, err = mod.toggle_like(graphql_url, tok, pid)
                if ok:
                    applied += 1
                    completed_keys.add(key)
                    if checkpoint_path:
                        save_checkpoint(checkpoint_path, plan_fp, completed_keys)
                else:
                    errors.append({"liker": liker, "postId": pid, "phase": "toggle", "error": err or "?"})
            mod._report_like_progress(
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
        "liker_list": str(args.liker_list),
    }
    SUMMARY_PATH.write_text(json.dumps(out, indent=2), encoding="utf-8")
    print(json.dumps({k: out[k] for k in ("likes_applied", "skipped_already_liked", "error_count")}, indent=2))
    print(f"Summary: {SUMMARY_PATH}")
    if errors:
        sys.exit(1)


if __name__ == "__main__":
    main()
