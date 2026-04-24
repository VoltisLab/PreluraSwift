#!/usr/bin/env python3
"""
Assign one unique profile image per female seed username (115 accounts).

Rules:
  • Usernames come from scripts/data/seed-usernames-female.txt (exactly one list - never male accounts).
  • Image folder must contain the same number of image files as usernames (default: 115).
  • Images are sorted by filename (case-insensitive) for a stable, repeatable pairing with file order.
  • Each image is used at most once.

Flow per account: login → multipart upload (PROFILE_PICTURE) → updateProfile with URLs.
Matches Prelura iOS FileUploadService + UserService.updateProfilePicture.

Env:
  STAGING_SEED_PASSWORD   required (unless --dry-run)
  GRAPHQL_URL             default https://prelura.voltislabs.uk/graphql/
  UPLOAD_URL              default https://prelura.voltislabs.uk/graphql/uploads/
  SEED_EMAIL_DOMAIN       default mywearhouse.co.uk (second login attempt)

Examples:
  python3 scripts/apply_female_seed_profile_pictures.py --dry-run ~/Downloads/female-avatars
  STAGING_SEED_PASSWORD='…' python3 scripts/apply_female_seed_profile_pictures.py ~/Downloads/female-avatars
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import tempfile
import uuid
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

# -----------------------------------------------------------------------------
# Defaults (see Prelura-swift/Utilities/Constants.swift)
# -----------------------------------------------------------------------------
DEFAULT_GRAPHQL = "https://prelura.voltislabs.uk/graphql/"
DEFAULT_UPLOAD = "https://prelura.voltislabs.uk/graphql/uploads/"

LOGIN_MUTATION = """mutation Login($username: String!, $password: String!) {
  login(username: $username, password: $password) {
    token
    refreshToken
    user { id username email }
  }
}"""

UPLOAD_MUTATION = """mutation UploadFile($files: [Upload]!, $fileType: FileTypeEnum!) {
  upload(files: $files, filetype: $fileType) { baseUrl data }
}"""

UPDATE_PROFILE_MUTATION = """mutation UpdateProfilePicture($profilePicture: ProfilePictureInputType) {
  updateProfile(profilePicture: $profilePicture) { message }
}"""

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".heic", ".heif", ".webp", ".gif", ".bmp", ".tif", ".tiff"}


def repo_root() -> Path:
    return Path(__file__).resolve().parent.parent


def load_usernames(list_path: Path) -> list[str]:
    lines = list_path.read_text(encoding="utf-8").splitlines()
    out = [ln.strip() for ln in lines if ln.strip()]
    return out


def load_map_tsv(map_path: Path, image_dir: Path) -> list[tuple[str, Path]]:
    """
    TSV from scripts/data/female-seed-avatar-map.tsv:
      index \\t username \\t image_filename
    """
    lines = map_path.read_text(encoding="utf-8").splitlines()
    if not lines:
        return []
    pairs: list[tuple[str, Path]] = []
    start = 1 if lines[0].lower().startswith("index\t") else 0
    for ln in lines[start:]:
        if not ln.strip():
            continue
        parts = ln.split("\t")
        if len(parts) < 3:
            continue
        username, fname = parts[1].strip(), parts[2].strip()
        p = (image_dir / fname).resolve()
        if not p.is_file():
            raise SystemExit(f"Map references missing file: {p}")
        pairs.append((username, p))
    return pairs


def list_image_files(image_dir: Path) -> list[Path]:
    files: list[Path] = []
    for p in image_dir.iterdir():
        if not p.is_file():
            continue
        if p.suffix.lower() in IMAGE_EXTENSIONS:
            files.append(p)
    files.sort(key=lambda x: x.name.lower())
    return files


def ensure_jpeg(path: Path) -> tuple[Path, bool]:
    """Return (path_to_jpeg_bytes_readable, should_unlink)."""
    suf = path.suffix.lower()
    if suf in (".jpg", ".jpeg"):
        return path, False
    fd, tmp_str = tempfile.mkstemp(suffix=".jpg", prefix="prelura_avatar_")
    os.close(fd)
    tmp = Path(tmp_str)
    try:
        subprocess.run(
            ["sips", "-s", "format", "jpeg", str(path), "--out", str(tmp)],
            check=True,
            capture_output=True,
            text=True,
        )
    except (subprocess.CalledProcessError, FileNotFoundError) as e:
        tmp.unlink(missing_ok=True)
        raise SystemExit(
            f"Could not convert {path} to JPEG (need macOS `sips`, or provide .jpg/.jpeg). {e}"
        ) from e
    return tmp, True


def graphql_json(url: str, payload: dict[str, Any], token: str | None = None) -> dict[str, Any]:
    data = json.dumps(payload).encode("utf-8")
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = Request(url, data=data, headers=headers, method="POST")
    try:
        with urlopen(req, timeout=120) as resp:
            body = resp.read().decode("utf-8")
    except HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        raise SystemExit(f"HTTP {e.code} from GraphQL: {body[:2000]}") from e
    except URLError as e:
        raise SystemExit(f"Network error: {e}") from e
    return json.loads(body)


def login(graphql_url: str, password: str, username: str, email_domain: str) -> str:
    variables = {"username": username, "password": password}
    payload = {"query": LOGIN_MUTATION, "variables": variables}
    r = graphql_json(graphql_url, payload)
    if r.get("errors"):
        if "@" not in username:
            email = f"{username}@{email_domain}"
            payload["variables"] = {"username": email, "password": password}
            r = graphql_json(graphql_url, payload)
    if r.get("errors"):
        raise RuntimeError(json.dumps(r["errors"], indent=2))
    tok = (r.get("data") or {}).get("login", {}).get("token")
    if not tok:
        raise RuntimeError(f"No token in response: {json.dumps(r)[:800]}")
    return tok


def build_upload_body(jpeg_data: bytes, boundary: str) -> bytes:
    operations = {
        "query": UPLOAD_MUTATION,
        "variables": {"files": [None], "fileType": "PROFILE_PICTURE"},
    }
    parts: list[bytes] = []
    crlf = b"\r\n"

    def add_field(name: str, value: bytes, content_type: str | None = None) -> None:
        parts.append(f"--{boundary}".encode("ascii") + crlf)
        disp = f'Content-Disposition: form-data; name="{name}"'
        parts.append(disp.encode("ascii") + crlf)
        if content_type:
            parts.append(f"Content-Type: {content_type}".encode("ascii") + crlf)
        parts.append(crlf + value + crlf)

    add_field("operations", json.dumps(operations).encode("utf-8"), "application/json")
    add_field("map", json.dumps({"0": ["variables.files.0"]}).encode("utf-8"), "application/json")
    parts.append(f"--{boundary}".encode("ascii") + crlf)
    parts.append(
        b'Content-Disposition: form-data; name="0"; filename="image.jpg"'
        + crlf
        + b"Content-Type: image/jpeg"
        + crlf
        + crlf
    )
    parts.append(jpeg_data + crlf)
    parts.append(f"--{boundary}--".encode("ascii") + crlf)
    return b"".join(parts)


def upload_profile_picture(upload_url: str, token: str, jpeg_data: bytes) -> tuple[str, str]:
    boundary = "----PreluraBoundary" + uuid.uuid4().hex
    body = build_upload_body(jpeg_data, boundary)
    headers = {
        "Content-Type": f"multipart/form-data; boundary={boundary}",
        "Authorization": f"Bearer {token}",
    }
    req = Request(upload_url, data=body, headers=headers, method="POST")
    with urlopen(req, timeout=300) as resp:
        raw = resp.read().decode("utf-8")
    r = json.loads(raw)
    if r.get("errors"):
        raise RuntimeError(json.dumps(r["errors"], indent=2))
    up = (r.get("data") or {}).get("upload")
    if not up:
        raise RuntimeError(f"Bad upload response: {raw[:1200]}")
    base_url = (up.get("baseUrl") or "").rstrip("/")
    data_arr = up.get("data") or []
    if not data_arr:
        raise RuntimeError("upload.data empty")
    inner = json.loads(data_arr[0])
    image_path = inner["image"]
    thumb_path = inner["thumbnail"]
    full = f"{base_url}/{image_path}" if base_url else image_path
    thumb = f"{base_url}/{thumb_path}" if base_url else thumb_path
    return full, thumb


def update_profile(graphql_url: str, token: str, profile_url: str, thumb_url: str) -> None:
    payload = {
        "query": UPDATE_PROFILE_MUTATION,
        "variables": {
            "profilePicture": {
                "profilePictureUrl": profile_url,
                "thumbnailUrl": thumb_url,
            }
        },
    }
    r = graphql_json(graphql_url, payload, token=token)
    if r.get("errors"):
        raise RuntimeError(json.dumps(r["errors"], indent=2))


def main() -> None:
    ap = argparse.ArgumentParser(description="Apply unique profile pictures to female seed accounts.")
    ap.add_argument(
        "image_dir",
        type=Path,
        help="Folder containing exactly N images (N = usernames in list file)",
    )
    ap.add_argument(
        "--list",
        type=Path,
        default=None,
        help=f"Username list (default: {repo_root() / 'scripts/data/seed-usernames-female.txt'})",
    )
    ap.add_argument(
        "--dry-run",
        action="store_true",
        help="Print username ↔ image pairs only; no network calls",
    )
    ap.add_argument(
        "--skip",
        type=int,
        default=0,
        help="Skip the first K pairs (resume after partial run)",
    )
    ap.add_argument(
        "--map",
        type=Path,
        default=None,
        metavar="TSV",
        help="Optional TSV (index, username, image_filename): pair accounts to named files in image_dir "
        "instead of sorting filenames. Use when the folder has fewer images than the full female list.",
    )
    args = ap.parse_args()

    image_dir = args.image_dir.expanduser().resolve()
    if not image_dir.is_dir():
        sys.exit(f"Not a directory: {image_dir}")

    if args.map:
        map_path = args.map.expanduser().resolve()
        if not map_path.is_file():
            sys.exit(f"Missing --map file: {map_path}")
        pairs = load_map_tsv(map_path, image_dir)
        if not pairs:
            sys.exit(f"No rows loaded from {map_path}")
        n_user = len(pairs)
    else:
        list_path = args.list or (repo_root() / "scripts/data/seed-usernames-female.txt")
        if not list_path.is_file():
            sys.exit(f"Missing username list: {list_path}")

        usernames = load_usernames(list_path)
        images = list_image_files(image_dir)
        n_user = len(usernames)
        n_img = len(images)

        if n_user != n_img:
            sys.exit(
                f"Count mismatch: {n_user} usernames in {list_path.name} but {n_img} images in {image_dir} "
                f"(need exactly {n_user} image files, or use --map with a partial TSV)."
            )

        pairs = list(zip(usernames, images))
    total_all = len(pairs)
    if args.skip:
        pairs = pairs[args.skip :]

    if args.dry_run:
        print("# username\timage_path")
        for u, p in pairs:
            print(f"{u}\t{p}")
        print(f"# pairs: {len(pairs)} of {total_all} (skip={args.skip})")
        return

    password = os.environ.get("STAGING_SEED_PASSWORD", "").strip()
    if not password:
        sys.exit("Set STAGING_SEED_PASSWORD (or use --dry-run).")

    graphql_url = os.environ.get("GRAPHQL_URL", DEFAULT_GRAPHQL).rstrip("/") + "/"
    upload_url = os.environ.get("UPLOAD_URL", DEFAULT_UPLOAD)
    if not upload_url.endswith("/"):
        upload_url += "/"
    email_domain = os.environ.get("SEED_EMAIL_DOMAIN", "mywearhouse.co.uk")

    for j, (username, img_path) in enumerate(pairs):
        step = args.skip + j + 1
        print(f"[{step}/{total_all}] {username} ← {img_path.name}", flush=True)
        tmp: Path | None = None
        try:
            print("    … prepare image", flush=True)
            jpeg_path, need_unlink = ensure_jpeg(img_path)
            if need_unlink:
                tmp = jpeg_path
            jpeg_data = jpeg_path.read_bytes()
            print(f"    … login ({len(jpeg_data) // 1024} KB JPEG)", flush=True)
            token = login(graphql_url, password, username, email_domain)
            print("    … upload (multipart)", flush=True)
            full, thumb = upload_profile_picture(upload_url, token, jpeg_data)
            print("    … updateProfile", flush=True)
            update_profile(graphql_url, token, full, thumb)
            print("    OK", flush=True)
        except Exception as e:
            print(f"    FAIL: {e}", flush=True)
            sys.exit(1)
        finally:
            if tmp is not None:
                tmp.unlink(missing_ok=True)

    print("Done.", flush=True)


if __name__ == "__main__":
    main()
