#!/usr/bin/env python3
"""
Seed Lookbook posts from Activewear image folders (men + women).

  • Men: max 2 posts per user (male seed list: scripts/data/seed-usernames-male.txt).
  • Women: max 3 posts per user (female seed list: scripts/data/seed-usernames-female.txt).
  • Up to 50 posts get a caption (mix of short text, emoji-only, and realistic lines).
  • ~70% of posts include hashtags; ≥50% of those use 2–5 tags (hard cap 5).
    Primary tag #activewear appears in ~90% of hashtag blocks; fillers are gym/fit TikTok–style.
  • Optional comments from other seed users (emoji or short text).

Env: STAGING_SEED_PASSWORD (required), GRAPHQL_URL, UPLOAD_URL, SEED_EMAIL_DOMAIN.

  STAGING_SEED_PASSWORD='…' python3 scripts/seed_activewear_lookbook.py \\
    "/Users/user/Downloads/Men compressed" \\
    "/Users/user/Downloads/Women Compressed"
"""
from __future__ import annotations

import argparse
import json
import os
import random
import subprocess
import sys
import tempfile
import uuid
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

DEFAULT_GRAPHQL = "https://prelura.voltislabs.uk/graphql/"
DEFAULT_UPLOAD = "https://prelura.voltislabs.uk/graphql/uploads/"

LOGIN_MUTATION = """mutation Login($username: String!, $password: String!) {
  login(username: $username, password: $password) {
    token refreshToken user { id username email }
  }
}"""

UPLOAD_MUTATION = """mutation UploadFile($files: [Upload]!, $fileType: FileTypeEnum!) {
  upload(files: $files, filetype: $fileType) { baseUrl data }
}"""

CREATE_LOOKBOOK = """mutation CreateLookbook($imageUrl: String!, $caption: String) {
  createLookbook(imageUrl: $imageUrl, caption: $caption) {
    lookbookPost { id imageUrl caption username }
    success
    message
  }
}"""

ADD_COMMENT = """mutation AddLookbookComment($postId: UUID!, $text: String!, $parentCommentId: UUID) {
  addLookbookComment(postId: $postId, text: $text, parentCommentId: $parentCommentId) {
    success message commentsCount
    comment { id username text }
  }
}"""

IMAGE_EXT = {".jpg", ".jpeg", ".png", ".heic", ".heif", ".webp", ".gif", ".bmp", ".tif", ".tiff"}

# --- Up to 50 caption lines: athleisure / gym / running - some emoji-only for variety ---
CAPTION_POOL = [
    "💪",
    "✨",
    "🔥",
    "Leg day check.",
    "Easy miles, good vibes.",
    "Rest day fit still counts.",
    "Sweat first, scroll later.",
    "Compression + coffee.",
    "Yoga brain activated.",
    "Hot girl walk era.",
    "Post-run glow (or sweat, same thing).",
    "Sets and reps, then errands.",
    "Athleisure because life is a warm-up.",
    "Tank season is a mindset.",
    "Breathable fabric, questionable playlist.",
    "Training blocks > notifications.",
    "Mobility isn’t boring if it saves your knees.",
    "Matching set so I actually showed up.",
    "Gym bag packed like I’m going on tour.",
    "HR zone 2 and a podcast.",
    "Sunday reset in stretchy pants.",
    "If the sports bra passes the jump test, we’re good.",
    "Neutral palette, loud playlist.",
    "Half zip season.",
    "Ran out of excuses before I ran out of shoes.",
    "Core engaged (allegedly).",
    "Track pants, track mind.",
    "Lift heavy, hydrate heavier.",
    "Fit check before the treadmill wins.",
    "Bun secured. Workout unsecured.",
    "Anti-chafe technology appreciated.",
    "Shorts weather is a personality.",
    "Pilates princess / chaos gremlin.",
    "Recovery walk, dramatic sky.",
    "Gym lighting did its job.",
    "No PR today, just consistency.",
    "Stretching counts as productivity.",
    "Athletic socks - the real MVP.",
    "Morning miles hit different.",
    "Baggy tee, serious intent.",
    "Foam roller is my therapist.",
    "Steps in before Slack pings.",
    "Sweat wicking, drama repelling.",
    "Training plan: show up.",
    "Fitspo for people who forget water bottles.",
    "Bike commute hair, don’t care.",
    "Sun’s out, SPF’s on, we move.",
    "Low impact, high effort.",
    "Earned this hoodie.",
    "Reps > perfection.",
]

# Primary hashtag appears in ~90% of hashtag blocks (see build_hashtag_line)
TAG_PRIMARY = "activewear"
# Mix of IG/TikTok fitness tags - keep generic (no trademarked slogans)
TAG_ACTIVE = [
    "activewear",
    "athleisure",
    "gymfit",
    "fitspo",
    "gymtok",
    "fitnessmotivation",
    "workoutfit",
    "yogafit",
    "runningmotivation",
    "legday",
    "OOTD",
    "streetwear",
    "sportswear",
    "trainingday",
    "healthylifestyle",
    "fitnessjourney",
    "gymmotivation",
    "yoga",
    "pilates",
    "runnersofinstagram",
    "fitcheck",
    "outfitinspo",
    "sweatlife",
    "strongnotskinny",
]

COMMENT_POOL = [
    "🔥",
    "🙌",
    "😍",
    "✨",
    "👏",
    "💪",
    "Love this",
    "So clean",
    "Goals",
    "This fit 🔥",
    "Need this energy",
    "Perfect",
]


def repo_root() -> Path:
    return Path(__file__).resolve().parent.parent


def load_users(name: str) -> list[str]:
    p = repo_root() / "scripts/data" / name
    return [ln.strip() for ln in p.read_text(encoding="utf-8").splitlines() if ln.strip()]


def list_images(folder: Path) -> list[Path]:
    xs = [
        p
        for p in folder.iterdir()
        if p.is_file() and p.suffix.lower() in IMAGE_EXT and not p.name.startswith(".")
    ]
    xs.sort(key=lambda x: x.name.lower())
    return xs


def assign_men(male_users: list[str], images: list[Path], max_per: int = 2) -> list[tuple[str, Path]]:
    images = sorted(images, key=lambda x: x.name.lower())
    if len(images) > len(male_users) * max_per:
        raise SystemExit(
            f"Too many men images ({len(images)}) for max {max_per}/user across {len(male_users)} users"
        )
    need = (len(images) + max_per - 1) // max_per
    users = male_users[:need]
    out: list[tuple[str, Path]] = []
    for i, img in enumerate(images):
        u = users[i // max_per]
        out.append((u, img))
    return out


def assign_women(female_users: list[str], images: list[Path], max_per: int = 3) -> list[tuple[str, Path]]:
    users = female_users
    n = len(users)
    counts: dict[str, int] = {u: 0 for u in users}
    out: list[tuple[str, Path]] = []
    ui = 0
    for img in sorted(images, key=lambda x: x.name.lower()):
        placed = False
        for _ in range(n):
            u = users[ui % n]
            ui = (ui + 1) % n
            if counts[u] < max_per:
                out.append((u, img))
                counts[u] += 1
                placed = True
                break
        if not placed:
            raise SystemExit("Could not assign women images (increase user pool or reduce images)")
    return out


def ensure_jpeg(path: Path) -> tuple[Path, bool]:
    suf = path.suffix.lower()
    if suf in (".jpg", ".jpeg"):
        return path, False
    fd, tmp_str = tempfile.mkstemp(suffix=".jpg", prefix="prelura_lb_")
    os.close(fd)
    tmp = Path(tmp_str)
    subprocess.run(
        ["sips", "-s", "format", "jpeg", str(path), "--out", str(tmp)],
        check=True,
        capture_output=True,
        text=True,
    )
    return tmp, True


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


def upload_lookbook(token: str, upload_url: str, jpeg_data: bytes) -> str:
    boundary = "----PreluraBoundary" + uuid.uuid4().hex
    operations = {
        "query": UPLOAD_MUTATION,
        "variables": {"files": [None], "fileType": "LOOKBOOK"},
    }
    parts: list[bytes] = []
    crlf = b"\r\n"

    def add_field(name: str, value: bytes, ct: str | None = None) -> None:
        parts.append(f"--{boundary}".encode() + crlf)
        parts.append(f'Content-Disposition: form-data; name="{name}"'.encode() + crlf)
        if ct:
            parts.append(f"Content-Type: {ct}".encode() + crlf)
        parts.append(crlf + value + crlf)

    add_field("operations", json.dumps(operations).encode(), "application/json")
    add_field("map", json.dumps({"0": ["variables.files.0"]}).encode(), "application/json")
    parts.append(f"--{boundary}".encode() + crlf)
    parts.append(
        b'Content-Disposition: form-data; name="0"; filename="image.jpg"' + crlf + b"Content-Type: image/jpeg" + crlf + crlf
    )
    parts.append(jpeg_data + crlf)
    parts.append(f"--{boundary}--".encode() + crlf)
    body = b"".join(parts)
    req = Request(
        upload_url,
        data=body,
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}", "Authorization": f"Bearer {token}"},
        method="POST",
    )
    with urlopen(req, timeout=300) as resp:
        raw = resp.read().decode("utf-8")
    r = json.loads(raw)
    if r.get("errors"):
        raise RuntimeError(json.dumps(r["errors"]))
    up = (r.get("data") or {}).get("upload")
    if not up:
        raise RuntimeError(raw[:800])
    base_url = (up.get("baseUrl") or "").rstrip("/")
    data_arr = up.get("data") or []
    inner = json.loads(data_arr[0])
    image_path = inner["image"]
    return f"{base_url}/{image_path}" if base_url else image_path


def create_lookbook_post(token: str, graphql_url: str, image_url: str, caption: str | None) -> dict[str, Any]:
    variables: dict[str, Any] = {"imageUrl": image_url}
    if caption and caption.strip():
        variables["caption"] = caption.strip()
    r = graphql_json(
        graphql_url,
        {"query": CREATE_LOOKBOOK, "variables": variables},
        token=token,
    )
    if r.get("errors"):
        raise RuntimeError(json.dumps(r["errors"]))
    pl = (r.get("data") or {}).get("createLookbook")
    if not pl or not pl.get("lookbookPost"):
        raise RuntimeError(json.dumps(r)[:1200])
    return pl["lookbookPost"]


def add_comment(token: str, graphql_url: str, post_id: str, text: str) -> None:
    r = graphql_json(
        graphql_url,
        {
            "query": ADD_COMMENT,
            "variables": {"postId": post_id, "text": text, "parentCommentId": None},
        },
        token=token,
    )
    if r.get("errors"):
        raise RuntimeError(json.dumps(r["errors"]))
    pl = (r.get("data") or {}).get("addLookbookComment")
    if not pl or pl.get("success") is not True:
        raise RuntimeError(json.dumps(r)[:800])


def build_hashtag_line(rng: random.Random, multi: bool) -> str:
    """multi=True → 2–5 tags; else 1 tag. ~90% include #activewear (primary)."""
    use_primary = rng.random() < 0.90
    extras = [t for t in TAG_ACTIVE if t != TAG_PRIMARY]
    rng.shuffle(extras)

    if not multi:
        if use_primary:
            return f"#{TAG_PRIMARY}"
        return f"#{rng.choice(extras)}"

    need = rng.randint(2, 5)
    tags: list[str] = []
    if use_primary:
        tags.append(TAG_PRIMARY)
    else:
        tags.append(rng.choice(extras))
    for t in extras:
        if len(tags) >= need:
            break
        if t not in tags:
            tags.append(t)
    while len(tags) < need:
        x = rng.choice(TAG_ACTIVE)
        if x not in tags:
            tags.append(x)
    return " ".join(f"#{t}" for t in tags[:5])


def plan_posts(
    assignments: list[tuple[str, Path]],
    rng: random.Random,
    caption_n: int = 50,
    hashtag_ratio: float = 0.70,
    multi_of_hashtag_ratio: float = 0.50,
    comment_count: int = 45,
) -> list[dict[str, Any]]:
    n = len(assignments)
    indices = list(range(n))
    rng.shuffle(indices)
    caption_set = set(indices[: min(caption_n, n)])
    hashtag_n = int(round(n * hashtag_ratio))
    hashtag_set = set(rng.sample(indices, min(hashtag_n, n)))
    hashtag_list = list(hashtag_set)
    rng.shuffle(hashtag_list)
    multi_n = int(round(len(hashtag_list) * multi_of_hashtag_ratio))
    multi_set = set(hashtag_list[:multi_n])

    caps = list(CAPTION_POOL)
    rng.shuffle(caps)

    planned: list[dict[str, Any]] = []
    cap_i = 0
    for idx, (user, path) in enumerate(assignments):
        in_cap = idx in caption_set
        in_hash = idx in hashtag_set
        multi_h = idx in multi_set
        body = ""
        if in_cap:
            body = caps[cap_i % len(caps)]
            cap_i += 1
        tag_line = ""
        if in_hash:
            tag_line = build_hashtag_line(rng, multi=multi_h)
        parts = []
        if body:
            parts.append(body)
        if tag_line:
            parts.append(tag_line)
        caption = " ".join(parts).strip() if parts else None
        planned.append(
            {
                "username": user,
                "image": str(path),
                "caption": caption,
                "flags": {"text_caption": in_cap, "hashtags": in_hash, "multi_hashtag": multi_h},
            }
        )

    comment_idxs = rng.sample(indices, min(comment_count, n))
    for i, row in enumerate(planned):
        row["add_comment"] = i in comment_idxs
    return planned


def pick_commenter(poster: str, all_users: list[str], rng: random.Random) -> str:
    candidates = [u for u in all_users if u != poster]
    return rng.choice(candidates)


def print_account_summary(report: dict[str, Any]) -> None:
    print("\n--- Account summary ---", flush=True)
    print(
        f"  Male: {report['unique_male_accounts']} accounts, {report['men_posts']} posts (cap 2/user).",
        flush=True,
    )
    print(
        f"  Female: {report['unique_female_accounts']} accounts, {report['women_posts']} posts (cap 3/user).",
        flush=True,
    )
    print(
        f"  Captions (from pool of {len(CAPTION_POOL)} lines): {report['captions_with_text']} posts.",
        flush=True,
    )
    print(
        f"  Hashtags: {report['posts_with_hashtags']}/{report['total_posts']} posts "
        f"({100.0 * report['posts_with_hashtags'] / max(1, report['total_posts']):.1f}%). "
        f"Multi-tag (2–5) among hashtag posts: {report.get('fraction_hashtag_posts_with_multi', 0):.0%}.",
        flush=True,
    )
    print("  Male usernames:", ", ".join(report["male_accounts_touched"]), flush=True)
    print("  Female usernames:", ", ".join(report["female_accounts_touched"]), flush=True)


def main() -> None:
    ap = argparse.ArgumentParser(
        description="Seed Lookbook activewear posts from separate Men and Women image folders."
    )
    ap.add_argument("men_dir", type=Path, help='Folder of men’s images (e.g. "Men compressed")')
    ap.add_argument("women_dir", type=Path, help='Folder of women’s images (e.g. "Women Compressed")')
    ap.add_argument("--limit", type=int, default=0, help="Only process first N total posts (debug)")
    ap.add_argument("--seed", type=int, default=42)
    args = ap.parse_args()

    men_dir = args.men_dir.expanduser().resolve()
    women_dir = args.women_dir.expanduser().resolve()
    if not men_dir.is_dir():
        sys.exit(f"Not a directory: {men_dir}")
    if not women_dir.is_dir():
        sys.exit(f"Not a directory: {women_dir}")

    male_users = load_users("seed-usernames-male.txt")
    female_users = load_users("seed-usernames-female.txt")
    men_imgs = list_images(men_dir)
    women_imgs = list_images(women_dir)
    if not men_imgs:
        sys.exit(f"No images in {men_dir}")
    if not women_imgs:
        sys.exit(f"No images in {women_dir}")

    men_assign = assign_men(male_users, men_imgs, max_per=2)
    women_assign = assign_women(female_users, women_imgs, max_per=3)
    all_assign = [(u, p, "m") for u, p in men_assign] + [(u, p, "f") for u, p in women_assign]
    rng = random.Random(args.seed)
    planned = plan_posts([(a[0], a[1]) for a in all_assign], rng)

    for i, row in enumerate(planned):
        row["gender"] = all_assign[i][2]
        row["image_path"] = all_assign[i][1]

    if args.limit > 0:
        planned = planned[: args.limit]

    summary_path = repo_root() / "scripts/data/activewear_lookbook_seed_summary.json"

    touched_m: dict[str, int] = {}
    touched_f: dict[str, int] = {}
    for row in planned:
        u = row["username"]
        if row["gender"] == "m":
            touched_m[u] = touched_m.get(u, 0) + 1
        else:
            touched_f[u] = touched_f.get(u, 0) + 1

    hashtag_posts = [r for r in planned if r["flags"]["hashtags"]]
    multi_among_hashtag = sum(1 for r in hashtag_posts if r["flags"]["multi_hashtag"])

    report = {
        "men_images_dir": str(men_dir),
        "women_images_dir": str(women_dir),
        "total_posts": len(planned),
        "men_posts": sum(1 for r in planned if r["gender"] == "m"),
        "women_posts": sum(1 for r in planned if r["gender"] == "f"),
        "unique_male_accounts": len(touched_m),
        "unique_female_accounts": len(touched_f),
        "male_accounts_touched": sorted(touched_m.keys()),
        "female_accounts_touched": sorted(touched_f.keys()),
        "posts_per_male": touched_m,
        "posts_per_female": touched_f,
        "notes": (
            "Male seed users: scripts/data/seed-usernames-male.txt (max 2 posts each for men’s images). "
            "Female seed users: scripts/data/seed-usernames-female.txt (max 3 posts each for women’s images). "
            "Up to 50 captions from a fixed pool (mix of text and emoji-only). "
            "~70% of posts get hashtags; ~50% of those use 2–5 tags; primary #activewear in ~90% of hashtag blocks."
        ),
        "captions_with_text": sum(1 for r in planned if r["flags"]["text_caption"]),
        "posts_with_hashtags": sum(1 for r in planned if r["flags"]["hashtags"]),
        "multi_hashtag_posts": sum(1 for r in planned if r["flags"]["multi_hashtag"]),
        "multi_hashtag_among_hashtag_posts": multi_among_hashtag,
        "fraction_hashtag_posts_with_multi": (
            round(multi_among_hashtag / len(hashtag_posts), 4) if hashtag_posts else 0.0
        ),
    }

    password = os.environ.get("STAGING_SEED_PASSWORD", "").strip()
    if not password:
        sys.exit("Set STAGING_SEED_PASSWORD")

    graphql_url = os.environ.get("GRAPHQL_URL", DEFAULT_GRAPHQL).rstrip("/") + "/"
    upload_url = os.environ.get("UPLOAD_URL", DEFAULT_UPLOAD)
    if not upload_url.endswith("/"):
        upload_url += "/"
    email_domain = os.environ.get("SEED_EMAIL_DOMAIN", "mywearhouse.co.uk")
    all_seed = male_users + female_users

    results: list[dict[str, Any]] = []
    for i, row in enumerate(planned, start=1):
        poster = row["username"]
        img_path = Path(row["image"])
        print(f"[{i}/{len(planned)}] post as {poster} ← {img_path.name}", flush=True)
        tmp: Path | None = None
        try:
            jp, need_unlink = ensure_jpeg(img_path)
            if need_unlink:
                tmp = jp
            data = jp.read_bytes()
            tok = login(graphql_url, password, poster, email_domain)
            url = upload_lookbook(tok, upload_url, data)
            post = create_lookbook_post(tok, graphql_url, url, row.get("caption"))
            pid = post.get("id")
            print(f"    created post id={pid}", flush=True)
            entry = {"poster": poster, "postId": pid, "image": str(img_path)}
            if row.get("add_comment") and pid:
                cname = pick_commenter(poster, all_seed, rng)
                ctok = login(graphql_url, password, cname, email_domain)
                ctext = rng.choice(COMMENT_POOL)
                add_comment(ctok, graphql_url, pid, ctext)
                entry["comment_from"] = cname
                entry["comment"] = ctext
                print(f"    comment from {cname}: {ctext!r}", flush=True)
            results.append(entry)
        except Exception as e:
            print(f"    FAIL: {e}", flush=True)
            sys.exit(1)
        finally:
            if tmp is not None:
                tmp.unlink(missing_ok=True)

    report["results"] = results
    report["graphql"] = graphql_url
    summary_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("Done.", flush=True)
    print_account_summary(report)
    print(f"Summary written: {summary_path}")


if __name__ == "__main__":
    main()
