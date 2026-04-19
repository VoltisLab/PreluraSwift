#!/usr/bin/env python3
"""
Seed Lookbook posts for **Boho** style from separate Men / Women image folders.

  • Men: max 2 posts per user (scripts/data/seed-usernames-male.txt).
  • Women: max 3 posts per user (scripts/data/seed-usernames-female.txt).
  • Up to 50 posts get a caption (mix of short text + emoji-only lines).
  • ~70% of posts include hashtags; ≥50% of those use 2–5 tags (max 5).
    Primary hashtag #boho in ~90% of hashtag blocks (IG/TikTok-style fillers).
  • ≥50% of posts request **StyleEnum BOHO** via GraphQL when the API supports
    ``createLookbook(..., styles: [...])``; otherwise retries without styles (see summary).
  • ~20% of posts get a comment; commenters are **same gender only** as the poster.
    ~40% of comments are emoji-only; the rest short text.

  Required: STAGING_SEED_PASSWORD. Optional: GRAPHQL_URL, UPLOAD_URL, SEED_EMAIL_DOMAIN.

  STAGING_SEED_PASSWORD='…' python3 scripts/seed_boho_lookbook.py \\
    "/Users/user/Downloads/Boho/Men" \\
    "/Users/user/Downloads/Boho/Women"
"""
from __future__ import annotations

import argparse
import json
import math
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

# Backend StyleEnum raw (see StyleEnumCatalog.swift)
STYLE_BOHO = "BOHO"

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

CREATE_LOOKBOOK_WITH_STYLES = """mutation CreateLookbook($imageUrl: String!, $caption: String, $styles: [StyleEnum!]) {
  createLookbook(imageUrl: $imageUrl, caption: $caption, styles: $styles) {
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

# Exactly 50 caption lines — boho / flowy / festival / earthy (some emoji-only)
CAPTION_POOL = [
    "🌾",
    "✨",
    "🤎",
    "Flowy fabric, zero stress.",
    "Earth tones and easy layers.",
    "Fringe season is a mindset.",
    "Desert sunset palette.",
    "Crochet weather (finally).",
    "Wanderlust in one outfit.",
    "Linen brain, soft schedule.",
    "Festival energy without the crowd.",
    "Stacked rings, stacked textures.",
    "Tapestry vibes, city streets.",
    "Bell sleeves don’t negotiate.",
    "Suede boots, long walk energy.",
    "Macramé mood on repeat.",
    "Patchwork heart, clean lines.",
    "Sun-faded denim, fresh air.",
    "Peasant top, main character.",
    "Paisley because why not.",
    "Oversized hat, undersized plans.",
    "Straw bag, real coffee.",
    "Embroidery details > logo flex.",
    "Flowy maxi, tight schedule (not).",
    "Amber jewelry and amber light.",
    "Barefoot grass, dressed for dinner.",
    "Vintage band tee, boho skirt math.",
    "Kimono layer for the breeze.",
    "Tassel earrings, loud silence.",
    "Clash prints like you mean it.",
    "Mood: open road, soft playlist.",
    "Cactus and cotton kind of day.",
    "Burnout? Never heard of her — burnout velvet though.",
    "Sheer sleeve, solid confidence.",
    "Raffia, rattan, repeat.",
    "Cowboy boots meet crochet trim.",
    "Moodboard: Coachella parking lot.",
    "Turquoise pop on neutral base.",
    "Slip dress + chunky knit = balance.",
    "Sun hat shadow, golden hour fit.",
    "Patch pockets, patch soul.",
    "Driftwood tones, sharp silhouette.",
    "Braid in my hair, breeze in the fabric.",
    "Soft glam, hard sunlight.",
    "Tiered skirt, tiered iced coffee.",
    "Muse: dusty road playlist.",
    "Charm necklace chaos (curated).",
    "Lace trim trust issues: none.",
    "Sand between toes, fit still clean.",
    "Mood ring green, outfit earth.",
]

# Primary tag ~90% in hashtag builder; large pool mirrors IG/TikTok boho tags
TAG_PRIMARY = "boho"
TAG_BOHO = [
    "boho",
    "bohostyle",
    "bohochic",
    "bohovibes",
    "bohoaesthetic",
    "bohoinspo",
    "festivaloutfit",
    "festivalfashion",
    "coachellaoutfit",
    "desertvibes",
    "earthtones",
    "flowyfashion",
    "crochet",
    "fringestyle",
    "maxidress",
    "layeredjewelry",
    "hippiechic",
    "wanderlust",
    "freepeoplevibes",
    "summerboho",
    "springboho",
    "bohomen",
    "bohowomen",
    "outfitinspo",
    "ootd",
    "fitcheck",
    "fashiontiktok",
    "instaboho",
    "bohofashion",
    "naturalstyle",
    "artisanvibes",
    "vintageboho",
    "boholife",
    "gypset",
    "etherealstyle",
    "neutralpalette",
    "strawhat",
    "suede",
    "laceandlinen",
    "printclash",
    "70svibes",
    "bohogram",
]

COMMENT_EMOJI = ["🔥", "🙌", "😍", "✨", "👏", "🌾", "🤎", "💫", "💯", "✌️", "🫶", "🌻"]

COMMENT_TEXT = [
    "So good",
    "Love this",
    "Boho goals",
    "Yes",
    "This vibe",
    "Need this fit",
    "Obsessed",
    "Stunning",
    "Clean",
    "Those textures",
    "Perfect energy",
    "Saving this",
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


def _extract_create_payload(r: dict[str, Any]) -> dict[str, Any] | None:
    pl = (r.get("data") or {}).get("createLookbook")
    if pl and pl.get("lookbookPost"):
        return pl["lookbookPost"]
    return None


def create_lookbook_post(
    token: str,
    graphql_url: str,
    image_url: str,
    caption: str | None,
    styles: list[str] | None = None,
) -> tuple[dict[str, Any], bool]:
    base_vars: dict[str, Any] = {"imageUrl": image_url}
    if caption and caption.strip():
        base_vars["caption"] = caption.strip()

    if styles:
        variables = dict(base_vars)
        variables["styles"] = styles
        r = graphql_json(
            graphql_url,
            {"query": CREATE_LOOKBOOK_WITH_STYLES, "variables": variables},
            token=token,
        )
        post = _extract_create_payload(r)
        if post is not None and not r.get("errors"):
            return post, True
        if r.get("errors"):
            err_txt = json.dumps(r["errors"]).lower()
            if "styles" in err_txt or "styleenum" in err_txt or "unknown argument" in err_txt:
                pass
            else:
                raise RuntimeError(json.dumps(r["errors"]))

    r = graphql_json(
        graphql_url,
        {"query": CREATE_LOOKBOOK, "variables": base_vars},
        token=token,
    )
    if r.get("errors"):
        raise RuntimeError(json.dumps(r["errors"]))
    post = _extract_create_payload(r)
    if not post:
        raise RuntimeError(json.dumps(r)[:1200])
    return post, False


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
    """~90% include #boho as primary anchor."""
    use_primary = rng.random() < 0.90
    extras = [t for t in TAG_BOHO if t != TAG_PRIMARY]
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
        x = rng.choice(TAG_BOHO)
        if x not in tags:
            tags.append(x)
    return " ".join(f"#{t}" for t in tags[:5])


def plan_posts(
    assignments: list[tuple[str, Path, str]],
    rng: random.Random,
    male_users: list[str],
    female_users: list[str],
    caption_n: int = 50,
    hashtag_ratio: float = 0.70,
    multi_of_hashtag_ratio: float = 0.50,
    comment_ratio: float = 0.20,
    boho_style_ratio: float = 0.50,
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

    boho_n = max(0, math.ceil(n * boho_style_ratio))
    boho_set = set(rng.sample(indices, min(boho_n, n)))

    comment_n = int(round(n * comment_ratio))
    comment_set = set(rng.sample(indices, min(comment_n, n)))

    caps = list(CAPTION_POOL)
    rng.shuffle(caps)

    planned: list[dict[str, Any]] = []
    cap_i = 0
    for idx, (user, path, gender) in enumerate(assignments):
        in_cap = idx in caption_set
        in_hash = idx in hashtag_set
        multi_h = idx in multi_set
        in_boho = idx in boho_set
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
                "gender": gender,
                "flags": {
                    "text_caption": in_cap,
                    "hashtags": in_hash,
                    "multi_hashtag": multi_h,
                    "boho_style": in_boho,
                },
                "add_comment": idx in comment_set,
            }
        )
    return planned


def pick_commenter_same_gender(
    poster: str,
    gender: str,
    male_users: list[str],
    female_users: list[str],
    rng: random.Random,
) -> str:
    pool = male_users if gender == "m" else female_users
    candidates = [u for u in pool if u != poster]
    if not candidates:
        raise RuntimeError("No same-gender commenter available")
    return rng.choice(candidates)


def comment_body(rng: random.Random) -> str:
    if rng.random() < 0.40:
        return rng.choice(COMMENT_EMOJI)
    return rng.choice(COMMENT_TEXT)


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
        f"  Captions (pool size {len(CAPTION_POOL)}): {report['captions_with_text']} posts with text from pool.",
        flush=True,
    )
    print(
        f"  Hashtags: {report['posts_with_hashtags']}/{report['total_posts']} "
        f"({100.0 * report['posts_with_hashtags'] / max(1, report['total_posts']):.1f}%).",
        flush=True,
    )
    print(
        f"  Multi-tag among hashtag posts: {report.get('multi_hashtag_among_hashtag_posts', 0)}/"
        f"{max(1, report['posts_with_hashtags'])} "
        f"({100.0 * report.get('fraction_hashtag_posts_with_multi', 0):.1f}% of hashtag posts).",
        flush=True,
    )
    print(
        f"  Planned BOHO style: {report.get('planned_boho_style', 0)}/{report['total_posts']} "
        f"({report.get('fraction_boho_style', 0):.0%}).",
        flush=True,
    )
    print(
        f"  Planned comments (~{report.get('comment_ratio_target', 0):.0%}): {report.get('planned_comments', 0)} posts "
        f"(same-gender only; ~40% emoji).",
        flush=True,
    )
    print("  Male usernames touched:", ", ".join(report["male_accounts_touched"]), flush=True)
    print("  Female usernames touched:", ", ".join(report["female_accounts_touched"]), flush=True)


def main() -> None:
    ap = argparse.ArgumentParser(
        description="Seed Lookbook Boho posts from Men and Women image folders."
    )
    ap.add_argument("men_dir", type=Path)
    ap.add_argument("women_dir", type=Path)
    ap.add_argument("--limit", type=int, default=0)
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
    planned = plan_posts(all_assign, rng, male_users, female_users)

    for i, row in enumerate(planned):
        row["image_path"] = all_assign[i][1]

    if args.limit > 0:
        planned = planned[: args.limit]

    summary_path = repo_root() / "scripts/data/boho_lookbook_seed_summary.json"

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
    boho_n = sum(1 for r in planned if r["flags"]["boho_style"])

    report: dict[str, Any] = {
        "style": "BOHO",
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
            "Uses scripts/data/seed-usernames-male.txt and seed-usernames-female.txt. "
            "Men max 2 posts/user; women max 3. "
            f"Up to {len(CAPTION_POOL)} distinct caption lines assigned to a random subset of posts; "
            "some lines are emoji-only. "
            "~70% posts get hashtags; ~50% of hashtag posts use 2–5 tags; #boho in ~90% of hashtag blocks. "
            f"≥50% of posts request GraphQL style {STYLE_BOHO} when supported. "
            "~20% posts get comments (same-gender commenters; ~40% emoji comments)."
        ),
        "captions_with_text": sum(1 for r in planned if r["flags"]["text_caption"]),
        "posts_with_hashtags": sum(1 for r in planned if r["flags"]["hashtags"]),
        "multi_hashtag_posts": sum(1 for r in planned if r["flags"]["multi_hashtag"]),
        "multi_hashtag_among_hashtag_posts": multi_among_hashtag,
        "fraction_hashtag_posts_with_multi": (
            round(multi_among_hashtag / len(hashtag_posts), 4) if hashtag_posts else 0.0
        ),
        "planned_boho_style": boho_n,
        "fraction_boho_style": round(boho_n / max(1, len(planned)), 4),
        "planned_comments": sum(1 for r in planned if r["add_comment"]),
        "comment_ratio_target": 0.20,
        "tag_primary": TAG_PRIMARY,
        "hashtag_pool_size": len(TAG_BOHO),
    }

    password = os.environ.get("STAGING_SEED_PASSWORD", "").strip()
    if not password:
        sys.exit("Set STAGING_SEED_PASSWORD")

    graphql_url = os.environ.get("GRAPHQL_URL", DEFAULT_GRAPHQL).rstrip("/") + "/"
    upload_url = os.environ.get("UPLOAD_URL", DEFAULT_UPLOAD)
    if not upload_url.endswith("/"):
        upload_url += "/"
    email_domain = os.environ.get("SEED_EMAIL_DOMAIN", "wearhouse.co.uk")

    results: list[dict[str, Any]] = []
    styles_ok = 0
    styles_fallback = 0

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
            want_styles = row["flags"].get("boho_style", False)
            styles_list = [STYLE_BOHO] if want_styles else None
            post, accepted = create_lookbook_post(tok, graphql_url, url, row.get("caption"), styles_list)
            if want_styles:
                if accepted:
                    styles_ok += 1
                else:
                    styles_fallback += 1
            pid = post.get("id")
            if want_styles:
                print(f"    created post id={pid} boho_style_applied={accepted}", flush=True)
            else:
                print(f"    created post id={pid}", flush=True)
            entry: dict[str, Any] = {
                "poster": poster,
                "postId": pid,
                "image": str(img_path),
                "boho_style_requested": want_styles,
                "styles_applied": accepted if want_styles else None,
            }
            if row.get("add_comment") and pid:
                cname = pick_commenter_same_gender(poster, row["gender"], male_users, female_users, rng)
                ctok = login(graphql_url, password, cname, email_domain)
                ctext = comment_body(rng)
                add_comment(ctok, graphql_url, pid, ctext)
                entry["comment_from"] = cname
                entry["comment"] = ctext
                entry["comment_emoji_only"] = ctext in COMMENT_EMOJI
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
    report["create_lookbook_styles_boho_success"] = styles_ok
    report["create_lookbook_styles_fallback_no_styles_arg"] = styles_fallback
    summary_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("Done.", flush=True)
    print_account_summary(report)
    print(
        f"  API: BOHO accepted on {styles_ok} posts; "
        f"fell back without styles on {styles_fallback} posts (when style was requested).",
        flush=True,
    )
    print(f"Summary written: {summary_path}")


if __name__ == "__main__":
    main()
