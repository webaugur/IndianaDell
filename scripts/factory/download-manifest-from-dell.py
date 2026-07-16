#!/usr/bin/env python3
"""Re-download FactoryDocs MANIFEST-pre-crash.txt MISS files from Dell catalogs.

Uses the public Dell Version Control Catalog (downloads.dell.com/catalog/CatalogPC.cab)
to resolve package paths, then downloads slowly so disks can keep up.

Usage:
  python3 scripts/factory/download-manifest-from-dell.py
  python3 scripts/factory/download-manifest-from-dell.py --limit 5
  python3 scripts/factory/download-manifest-from-dell.py --dry-run
  python3 scripts/factory/download-manifest-from-dell.py --rate 1M --sleep 8

Service tag B1GMB42 / Precision T5810 — packages are public driver downloads.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FACTORY = ROOT / "FactoryDocs"
MANIFEST = FACTORY / "MANIFEST-pre-crash.txt"
DEFAULT_CATALOG_CAB = "https://downloads.dell.com/catalog/CatalogPC.cab"
DEFAULT_BASE = "https://downloads.dell.com"
UA = (
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36 IndianaDell-FactoryDocs/1.0"
)


def log(msg: str) -> None:
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)


def parse_miss_list(path: Path) -> list[str]:
    items: list[str] = []
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if line.startswith("MISS "):
            items.append(line[5:].strip())
    return items


def normalize_basename(name: str) -> str:
    """Strip Windows ' (1)' copy suffixes before extension."""
    return re.sub(r" \(\d+\)(\.[^.]+)$", r"\1", name)


def extract_package_ids(name: str) -> list[str]:
    """Pull likely Dell package IDs (5-char tokens) from a filename."""
    # Prefer tokens between underscores: _RXT5N_ or _RXT5N.
    ids = re.findall(r"(?:^|_)([A-Za-z0-9]{5})(?:_|\.|$)", name)
    # Also standalone 5-char in older ZPE names
    ids += re.findall(r"(?:^|[\s_-])([A-Za-z0-9]{5})(?:[\s_-]|\.|$)", name)
    # Filter noise words
    noise = {
        "AUDIO",
        "INPUT",
        "VIDEO",
        "SETUP",
        "WIN64",
        "WIN32",
        "WN64",
        "WN32",
        "INTEL",
        "DELL",
        "TERA1",
        "TERA2",
        "FORCE",
        "DRIVE",
        "FLASH",
        "FIRMW",
        "CAB",
        "ZIP",
        "EXE",
        "ZPE",
    }
    out: list[str] = []
    for i in ids:
        u = i.upper()
        if u in noise:
            continue
        if u not in out:
            out.append(u)
    return out


def download_file(url: str, dest: Path, limit_rate: str) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    part = dest.with_suffix(dest.suffix + ".part")
    cmd = [
        "curl",
        "-fL",
        "--retry",
        "3",
        "--retry-delay",
        "5",
        "-A",
        UA,
        "--limit-rate",
        limit_rate,
        "-C",
        "-",
        "-o",
        str(part),
        url,
    ]
    subprocess.run(cmd, check=True)
    part.rename(dest)


def fetch_catalog(cache_dir: Path) -> Path:
    cache_dir.mkdir(parents=True, exist_ok=True)
    cab = cache_dir / "CatalogPC.cab"
    xml = cache_dir / "CatalogPC.xml"
    if xml.is_file() and xml.stat().st_size > 1_000_000:
        log(f"Using cached catalog XML: {xml}")
        return xml
    log(f"Downloading Dell catalog: {DEFAULT_CATALOG_CAB}")
    download_file(DEFAULT_CATALOG_CAB, cab, limit_rate="5M")
    # Extract with 7z or cabextract
    for tool in (
        ["7z", "x", "-y", f"-o{cache_dir}", str(cab)],
        ["cabextract", "-d", str(cache_dir), str(cab)],
    ):
        try:
            subprocess.run(tool, check=True, capture_output=True)
            break
        except (FileNotFoundError, subprocess.CalledProcessError):
            continue
    if not xml.is_file():
        raise RuntimeError("Failed to extract CatalogPC.xml from catalog CAB")
    log(f"Catalog ready: {xml} ({xml.stat().st_size // 1_000_000} MB)")
    return xml


def build_indexes(xml_path: Path) -> tuple[dict[str, str], dict[str, str]]:
    """Return (basename_lower -> relative path, packageID -> relative path)."""
    log("Indexing catalog (UTF-16)…")
    text = xml_path.read_text(encoding="utf-16")
    by_name: dict[str, str] = {}
    by_pid: dict[str, str] = {}
    # path="FOLDER…/file" packageID="XXXXX"  OR reverse attribute order
    for m in re.finditer(
        r'packageID="([^"]+)"[^>]*\bpath="([^"]+)"',
        text,
        flags=re.IGNORECASE,
    ):
        pid, path = m.group(1), m.group(2)
        by_pid.setdefault(pid.upper(), path)
        by_name.setdefault(path.rsplit("/", 1)[-1].lower(), path)
    for m in re.finditer(
        r'\bpath="([^"]+)"[^>]*packageID="([^"]+)"',
        text,
        flags=re.IGNORECASE,
    ):
        path, pid = m.group(1), m.group(2)
        by_pid.setdefault(pid.upper(), path)
        by_name.setdefault(path.rsplit("/", 1)[-1].lower(), path)
    # Also index bare path= for components without packageID nearby
    for m in re.finditer(r'\bpath="(FOLDER[^"]+)"', text):
        path = m.group(1)
        by_name.setdefault(path.rsplit("/", 1)[-1].lower(), path)
    log(f"Index: {len(by_name)} basenames, {len(by_pid)} package IDs")
    return by_name, by_pid


def is_plausible_pkg_id(token: str) -> bool:
    """Dell package IDs are 5 chars with both letters and digits (e.g. RXT5N)."""
    if len(token) != 5 or not token.isalnum():
        return False
    return any(c.isalpha() for c in token) and any(c.isdigit() for c in token)


def resolve_path(
    rel: str,
    by_name: dict[str, str],
    by_pid: dict[str, str],
) -> tuple[str | None, str]:
    """Return (catalog_relpath or None, reason)."""
    base = Path(rel).name
    norm = normalize_basename(base)
    for candidate in (base, norm):
        p = by_name.get(candidate.lower())
        if p:
            return p, f"name:{candidate}"
    for pid in extract_package_ids(norm):
        if not is_plausible_pkg_id(pid):
            continue
        p = by_pid.get(pid)
        if p:
            return p, f"packageID:{pid}"
    return None, "unresolved"


def already_present(factory: Path, rel: str) -> Path | None:
    """Return path if a usable file already exists (including non-duplicate twin)."""
    dest = factory / rel
    if dest.is_file() and dest.stat().st_size > 0:
        return dest
    # Without (1) suffix
    base = Path(rel).name
    norm = normalize_basename(base)
    if norm != base:
        alt = dest.with_name(norm)
        if alt.is_file() and alt.stat().st_size > 0:
            return alt
    # Under same dir without _duplicates
    parts = Path(rel).parts
    if "_duplicates" in parts:
        stripped = Path(*[p for p in parts if p != "_duplicates"])
        alt = factory / stripped
        if alt.is_file() and alt.stat().st_size > 0:
            return alt
    # Search by basename under FactoryDocs (shallow categories)
    hits = list(factory.rglob(norm))
    hits = [h for h in hits if h.is_file() and h.stat().st_size > 0]
    if hits:
        return hits[0]
    return None


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--manifest", type=Path, default=MANIFEST)
    ap.add_argument("--factory", type=Path, default=FACTORY)
    ap.add_argument("--cache", type=Path, default=FACTORY / "_cache")
    ap.add_argument("--rate", default="1500k", help="curl --limit-rate (default 1500k)")
    ap.add_argument("--sleep", type=float, default=6.0, help="Seconds between downloads")
    ap.add_argument("--limit", type=int, default=0, help="Max new downloads (0=all)")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--base-url", default=DEFAULT_BASE)
    args = ap.parse_args()

    if not args.manifest.is_file():
        log(f"ERROR: manifest not found: {args.manifest}")
        return 1

    miss = parse_miss_list(args.manifest)
    log(f"MANIFEST MISS entries: {len(miss)}")

    xml = fetch_catalog(args.cache)
    by_name, by_pid = build_indexes(xml)

    log_path = args.factory / "_incoming" / "download-log.tsv"
    log_path.parent.mkdir(parents=True, exist_ok=True)
    if not log_path.is_file():
        log_path.write_text("status\trel\treason\turl\tbytes\n", encoding="utf-8")

    downloaded = 0
    skipped = 0
    failed = 0
    unresolved = 0

    for i, rel in enumerate(miss, 1):
        existing = already_present(args.factory, rel)
        if existing is not None:
            log(f"[{i}/{len(miss)}] SKIP present: {rel}  ({existing})")
            skipped += 1
            with log_path.open("a", encoding="utf-8") as fh:
                fh.write(f"skip_present\t{rel}\t{existing}\t\t\n")
            continue

        cat_path, reason = resolve_path(rel, by_name, by_pid)
        if not cat_path:
            log(f"[{i}/{len(miss)}] UNRESOLVED: {rel}")
            unresolved += 1
            with log_path.open("a", encoding="utf-8") as fh:
                fh.write(f"unresolved\t{rel}\t{reason}\t\t\n")
            continue

        url = f"{args.base_url.rstrip('/')}/{cat_path}"
        # Save using catalog basename under the manifest directory
        dest_dir = args.factory / str(Path(rel).parent)
        dest_name = cat_path.rsplit("/", 1)[-1]
        # Prefer exact manifest basename when normalized match
        man_base = normalize_basename(Path(rel).name)
        if man_base.lower() == dest_name.lower():
            dest = dest_dir / man_base
        else:
            dest = dest_dir / dest_name

        log(f"[{i}/{len(miss)}] GET ({reason}): {dest_name}")
        log(f"         {url}")
        if args.dry_run:
            continue

        try:
            download_file(url, dest, limit_rate=args.rate)
            sz = dest.stat().st_size
            log(f"         OK {sz // 1024} KiB -> {dest}")
            downloaded += 1
            with log_path.open("a", encoding="utf-8") as fh:
                fh.write(f"ok\t{rel}\t{reason}\t{url}\t{sz}\n")
        except Exception as e:
            failed += 1
            log(f"         FAIL: {e}")
            with log_path.open("a", encoding="utf-8") as fh:
                fh.write(f"fail\t{rel}\t{e}\t{url}\t\n")
            part = dest.with_suffix(dest.suffix + ".part")
            if part.is_file():
                part.unlink(missing_ok=True)

        if args.limit and downloaded >= args.limit:
            log(f"Reached --limit {args.limit}")
            break

        if args.sleep > 0 and not args.dry_run:
            time.sleep(args.sleep)

    log("---")
    log(f"downloaded={downloaded} skipped={skipped} unresolved={unresolved} failed={failed}")
    log(f"log: {log_path}")
    if unresolved:
        log("Tip: unresolved packages may be retired from the live catalog;")
        log("  try Dell support by package ID in the browser, drop into FactoryDocs/_incoming/")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
