#!/usr/bin/env python3
"""
Seed Lookbook posts from Office wear / Men + Women image folders.

  • Men: max 2 posts per user (uses first 32 male seed users for 64 images).
  • Women: max 3 posts per user (uses first 31 female seed users for 92 images).
  • Up to 50 posts get a text caption; hashtags go in the caption string (#tags).
  • ~70% of posts include hashtags; ~50% of those use 2–5 tags (cap 5); #minimalist in ~90% of hashtag lines.
  • Optional comments from other seed users (emoji or short text).

Env: STAGING_SEED_PASSWORD (required), GRAPHQL_URL, UPLOAD_URL, SEED_EMAIL_DOMAIN.

  STAGING_SEED_PASSWORD='…' python3 scripts/seed_officewear_lookbook.py "/Users/user/Downloads/Office wear"
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

# --- Caption pool (office / minimal aesthetic; mix lengths) ---
CAPTION_POOL = [
    "Monday uniform.",
    "Keeping it clean for the week ahead.",
    "Neutral palette, full focus.",
    "Desk to dinner if I swap the shoes.",
    "Tailoring that actually fits.",
    "Less noise, more fit.",
    "Soft light, sharp lines.",
    "Coffee first, then inbox.",
    "This blazer carries the whole look.",
    "Grey scale kind of day.",
    "Pressed shirt energy.",
    "Quiet luxury without the price tag talk.",
    "Straight leg, clean tuck.",
    "When the AC is aggressive but you still look pulled together.",
    "Notes app says: wear the good trousers.",
    "Minimal layers, maximum intention.",
    "Earbuds in, world out.",
    "That one necklace and done.",
    "Cropped just right.",
    "Sneakers with structure - not sorry.",
    "Black on black still counts as a palette.",
    "If it creases, I steam it. Simple.",
    "Meeting ran long; fit still held up.",
    "Borrowed from the boys, tailored for me.",
    "Shoulder line hits different.",
    "No logos, just fabric.",
    "Walked three blocks; shirt stayed tucked.",
    "The kind of outfit that ages well in photos.",
    "Clean hem, clean week.",
    "Muted tones, loud confidence.",
    "This is my “reply-all” armor.",
    "Texture play without the chaos.",
    "Waist definition without trying too hard.",
    "Slip dress season meets office AC.",
    "Cardigan because the office is Antarctica.",
    "Pumps that don’t hate me yet.",
    "Monochrome but not boring - fight me.",
    "Tailored enough for HR, cool enough for after.",
    "Fabric speaks; I’m just here.",
    "Small details: belt, watch, done.",
    "If you know, you know.",
    "Structured bag, soft knit - balance.",
    "Not chasing trends; chasing fit.",
    "Lighting did half the work.",
    "Same rotation, different knot.",
    "Wide leg era continues.",
    "Cropped blazer + high waist = easy math.",
    "Dress code: presentable human.",
    "Understated until you see the shoes.",
]

# Extra variety for when we need more than 50 unique lines (we only use 50 max)
CAPTION_EXTRA = [
    "Office air hits different in linen.",
    "Trust the process (and the tailor).",
]

# Hashtag pools - #minimalist appears in ~90% of generated hashtag blocks via builder
TAG_PRIMARY = "minimalist"
TAG_OFFICE = [
    "officewear",
    "workwear",
    "corporatestyle",
    "9to5style",
    "deskstyle",
    "cleanfit",
    "quietluxury",
    "capsulewardrobe",
    "neutraltones",
    "streetwear",
    "OOTD",
    "fashioninspo",
    "styleinspo",
    "outfitinspo",
    "fitcheck",
    "minimalstyle",
    "monochrome",
    "tailoring",
    "wardrobeessentials",
]

COMMENT_POOL = [
    "🔥",
    "🙌",
    "😍",
    "✨",
    "👏",
    "Love this",
    "So clean",
    "Yes!!",
    "This fit 🔥",
    "Obsessed",
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
        raise SystemExit(f"Too many men images ({len(images)}) for max {max_per}/user across {len(male_users)} users")
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
    """multi=True → 2–5 tags; else 1 tag. ~90% include #minimalist (primary)."""
    use_minimal = rng.random() < 0.90
    extras = [t for t in TAG_OFFICE if t != TAG_PRIMARY]
    rng.shuffle(extras)

    if not multi:
        if use_minimal:
            return f"#{TAG_PRIMARY}"
        return f"#{rng.choice(extras)}"

    # 2–5 tags; when use_minimal, always anchor with minimalist then add office/style tags.
    need = rng.randint(2, 5)
    tags: list[str] = []
    if use_minimal:
        tags.append(TAG_PRIMARY)
    else:
        tags.append(rng.choice(extras))
    for t in extras:
        if len(tags) >= need:
            break
        if t not in tags:
            tags.append(t)
    while len(tags) < need:
        x = rng.choice(TAG_OFFICE)
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

    caps = CAPTION_POOL + CAPTION_EXTRA
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

    # comment targets
    comment_idxs = rng.sample(indices, min(comment_count, n))
    for i, row in enumerate(planned):
        row["add_comment"] = i in comment_idxs
    return planned


def pick_commenter(poster: str, all_users: list[str], rng: random.Random) -> str:
    candidates = [u for u in all_users if u != poster]
    return rng.choice(candidates)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("office_wear_dir", type=Path, help="Path to Office wear (contains Men/ and Women/)")
    ap.add_argument("--limit", type=int, default=0, help="Only process first N total posts (debug)")
    ap.add_argument("--seed", type=int, default=42)
    args = ap.parse_args()
    base = args.office_wear_dir.expanduser().resolve()
    men_dir = base / "Men"
    women_dir = base / "Women"
    if not men_dir.is_dir() or not women_dir.is_dir():
        sys.exit(f"Need {men_dir} and {women_dir}")

    male_users = load_users("seed-usernames-male.txt")
    female_users = load_users("seed-usernames-female.txt")
    men_imgs = list_images(men_dir)
    women_imgs = list_images(women_dir)

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

    summary_path = repo_root() / "scripts/data/officewear_lookbook_seed_summary.json"

    touched_m: dict[str, int] = {}
    touched_f: dict[str, int] = {}
    for row in planned:
        u = row["username"]
        if row["gender"] == "m":
            touched_m[u] = touched_m.get(u, 0) + 1
        else:
            touched_f[u] = touched_f.get(u, 0) + 1

    report = {
        "office_wear_dir": str(base),
        "total_posts": len(planned),
        "men_posts": sum(1 for r in planned if r["gender"] == "m"),
        "women_posts": sum(1 for r in planned if r["gender"] == "f"),
        "unique_male_accounts": len(touched_m),
        "unique_female_accounts": len(touched_f),
        "male_accounts_touched": sorted(touched_m.keys()),
        "female_accounts_touched": sorted(touched_f.keys()),
        "posts_per_male": touched_m,
        "posts_per_female": touched_f,
        "captions_with_text": sum(1 for r in planned if r["flags"]["text_caption"]),
        "posts_with_hashtags": sum(1 for r in planned if r["flags"]["hashtags"]),
        "multi_hashtag_posts": sum(1 for r in planned if r["flags"]["multi_hashtag"]),
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
    print(f"Summary written: {summary_path}")


if __name__ == "__main__":
    main()
