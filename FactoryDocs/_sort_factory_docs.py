#!/usr/bin/env python3
"""Organize FactoryDocs: delete failed downloads, dedupe, sort by hardware/OS."""

from __future__ import annotations

import hashlib
import re
import shutil
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent
INCOMING = ROOT / "_incoming"
SKIP_NAMES = {
    "README.md",
    "_sort_factory_docs.py",
    "MANIFEST-pre-crash.txt",
    "MISSING-unresolved.txt",
    "LOCAL-INVENTORY.txt",
    "INDIANADELL-README.txt",
    "LICENSE",
    "CatalogPC.cab",
    "CatalogPC.xml",
}
# Never walk these trees (nested clones, caches, extracted docs)
SKIP_DIR_PARTS = {
    "WinPEDriverPack",
    "_cache",
    "_extracted",
    ".git",
    "_Misc",
}
FAILED_PATTERNS = (".crdownload", ".part", ".tmp", ".download")
FAILED_NAMES = ("Unconfirmed",)

RULES: list[tuple[str, callable]] = [
    ("_Misc/Software", lambda f: f.suffix.lower() == ".deb"),
    ("Expansion-Cards/PCIe-Serial/Documentation",
     lambda f: f.name == "serial-pcie-setup_en-us.pdf"),
    ("Expansion-Cards/Thunderbolt/Documentation",
     lambda f: f.name == "thunderbolt-pciecard.pdf"),
    ("System-T5810/Documentation",
     lambda f: f.suffix.lower() == ".pdf"),
    ("System-T5810/BIOS-Firmware/Cross-platform",
     lambda f: any(x in f.name for x in (
         "T5810A34", "GRV83_DBE_T5810", "FW_Flash_", "FimwareUpdateUtility",
         "FlashVer3.3.28", "PlatTagsSWB404", "CWX68_ZPE", "57DA4105",
         "15.201.2401_Desktop",
     ))),
    ("System-T5810/Windows-10", lambda f: "T5810-win10" in f.name),
    ("System-T5810/Windows-7", lambda f: "T5810-win7" in f.name),
    ("System-T5810/WinPE", lambda f: "WinPE" in f.name),
    ("System-T5810/Chipset/Windows",
     lambda f: f.name.startswith("Chipset_Driver")
     or "Management-Engine-Components" in f.name
     or "USB-eXtensible-Host-Controller" in f.name),
    ("System-T5810/Security-TPM/Windows",
     lambda f: any(x in f.name for x in (
         "DellTpm", "Dell-Encryption", "Dell-Security-Advisory", "DBUtil-Removal",
         "DDP_HCA", "Dell_DDP_Protected_Workspace",
     ))),
    ("GPU/AMD-FirePro/Windows",
     lambda f: any(x in f.name for x in ("AMD-FirePro", "Video_Driver_C5FPW"))),
    ("GPU/NVIDIA-Quadro/Windows",
     lambda f: any(x in f.name for x in (
         "NVIDIA-Quadro", "M2000-M4000-M5000-M6000", "Video_Firmware_NV_Quadro",
         "Video_ISV_Driver", "Video_Driver_71P4M", "quadro-desktop-whql",
         "Video_ISV_Driver_J4760",
     ))),
    ("GPU/NVIDIA-GeForce/Windows",
     lambda f: "GeForce" in f.name or "nVIDIA-GeForce" in f.name),
    ("GPU/AMD-RHEL/Cross-platform",
     lambda f: "dell-amd-rhel" in f.name.lower() or "amd-rhel" in f.name.lower()),
    ("Storage/RAID-Controller-PERC/Windows",
     lambda f: any(x in f.name for x in (
         "Storage-Controller_Driver", "LSI-9341", "LSI-9361",
     ))),
    ("Storage/Intel-RST/Windows",
     lambda f: "Rapid-Storage-Technology" in f.name
     or f.name.startswith("IRSTe_Driver")
     or "f6flpy" in f.name),
    ("Storage/Intel-PCIe-SSD-Driver/Windows",
     lambda f: "Intel-HHHL-PCIe-Solid-State-Drive" in f.name),
    ("Storage/HDD-Firmware/Cross-platform",
     lambda f: any(x in f.name for x in ("Seagate", "SAS-Drive_Firmware", "SeaFlash"))),
    ("Storage/SSD-Firmware/Cross-platform",
     lambda f: f.name.endswith("_ZPE.exe") and any(x in f.name for x in (
         "Intel SSD", "Samsung", "SanDisk", "SK", "Toshiba", "LiteOn", "Micron",
         "WD MZ", "WD XL",
     ))),
    ("Network/Intel-Ethernet/Windows",
     lambda f: any(x in f.name for x in (
         "Intel-Ethernet", "Intel-PCIe-Ethernet", "Network_Driver",
     ))),
    ("Network/Intel-Ethernet/Cross-platform", lambda f: "Intel PRO2500" in f.name),
    ("Audio/Windows", lambda f: f.name.startswith("Audio_")),
    ("Input/Windows", lambda f: f.name.startswith("Input_Driver")),
    ("Optical/BD-RE/Firmware", lambda f: "BD-RE" in f.name),
    ("Optical/DVD/Firmware", lambda f: "DH-16AES" in f.name),
    ("Expansion-Cards/PCIe-Serial/Windows", lambda f: "PCIe-Serial-Card" in f.name),
    ("Expansion-Cards/Thunderbolt/Firmware",
     lambda f: any(x in f.name for x in ("MSM16020004", "Tera1_and_Tera2"))),
    ("Expansion-Cards/PCoIP/Cross-platform", lambda f: "PcoipHostSoftware" in f.name),
    ("Dell-Management/Windows",
     lambda f: any(x in f.name for x in (
         "Dell-Command-", "Dell_Client_Management", "Dell_Repository_Manager",
         "DellCommandPowerShell", "STInstaller", "Application_",
         "Backup-and-Recovery",
     ))),
    ("Dell-Management/Cross-platform",
     lambda f: any(x in f.name for x in ("DCIS_", "DCIV_"))),
]


def classify(path: Path) -> str:
    probe = Path(clean_name(path.name))
    for dest, pred in RULES:
        if pred(probe):
            return dest
    return "_Unsorted"


def clean_name(name: str) -> str:
    name = re.sub(r" \(\d+\)(?=\.[^.]+$)", "", name)
    name = re.sub(r"\.zip\.zip$", ".zip", name, flags=re.IGNORECASE)
    return name


def is_failed(path: Path) -> bool:
    if any(path.name.endswith(s) for s in FAILED_PATTERNS):
        return True
    if any(path.name.startswith(p) for p in FAILED_NAMES):
        return True
    return False


def file_hash(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def keeper_score(path: Path) -> tuple:
    rel = path.relative_to(ROOT)
    parts = rel.parts
    in_incoming = "_incoming" in parts
    dup_suffix = 1 if re.search(r" \(\d+\)\.", path.name) else 0
    return (1 if in_incoming else 0, dup_suffix, len(parts), path.name.lower())


def should_skip_path(path: Path) -> bool:
    try:
        parts = set(path.relative_to(ROOT).parts)
    except ValueError:
        return True
    return bool(parts & SKIP_DIR_PARTS)


def iter_files() -> list[Path]:
    files: list[Path] = []
    for p in ROOT.rglob("*"):
        if not p.is_file() or p.name in SKIP_NAMES:
            continue
        if should_skip_path(p):
            continue
        if p.parent == ROOT and p.name == "_sort_factory_docs.py":
            continue
        if is_failed(p):
            continue
        # Only move real packages / docs, not random loose bits
        if p.suffix.lower() not in {
            ".exe", ".zip", ".cab", ".pdf", ".gz", ".tar", ".msi", ".deb",
        }:
            continue
        files.append(p)
    return files


def delete_failed() -> list[str]:
    removed: list[str] = []
    for p in list(ROOT.rglob("*")):
        if not p.is_file() or should_skip_path(p):
            continue
        if is_failed(p):
            removed.append(str(p.relative_to(ROOT)))
            p.unlink()
    return removed


def main() -> None:
    INCOMING.mkdir(exist_ok=True)
    failed = delete_failed()
    files = iter_files()
    by_hash: dict[str, list[Path]] = defaultdict(list)
    for f in files:
        by_hash[file_hash(f)].append(f)

    deleted: list[str] = []
    keepers: list[Path] = []
    for group in by_hash.values():
        group.sort(key=keeper_score)
        keepers.append(group[0])
        for extra in group[1:]:
            deleted.append(str(extra.relative_to(ROOT)))
            extra.unlink()

    moved: list[tuple[str, str]] = []
    for keeper in keepers:
        dest_dir = ROOT / classify(keeper)
        dest_dir.mkdir(parents=True, exist_ok=True)
        dest = dest_dir / clean_name(keeper.name)
        if keeper.resolve() == dest.resolve():
            continue
        if dest.exists() and file_hash(dest) == file_hash(keeper):
            deleted.append(str(keeper.relative_to(ROOT)))
            keeper.unlink()
            continue
        if dest.exists():
            dest = dest_dir / keeper.name
        shutil.move(str(keeper), str(dest))
        moved.append((keeper.name, str(dest.relative_to(ROOT))))

    for p in sorted(ROOT.rglob("_incoming"), reverse=True):
        if p.is_dir() and not any(p.iterdir()):
            p.rmdir()

    counts: dict[str, int] = defaultdict(int)
    for p in ROOT.rglob("*"):
        if p.is_file() and p.name not in SKIP_NAMES:
            top = p.relative_to(ROOT).parts[0]
            counts[top] += 1

    lines = [
        "# FactoryDocs Index",
        "",
        "Dell T5810 (B1GMB42) support packages — sorted by hardware, then OS.",
        f"Last run: removed {len(failed)} failed downloads, deleted {len(deleted)} duplicates.",
        "",
        "## Layout",
        "",
        "| Folder | Contents |",
        "|--------|----------|",
        "| `System-T5810/` | BIOS, chipset, ME, TPM, Win7/10 CAB, manuals |",
        "| `GPU/` | AMD FirePro, NVIDIA Quadro/GeForce |",
        "| `Storage/` | PERC H710, Intel RST, SSD/HDD firmware |",
        "| `Network/` | Intel Ethernet |",
        "| `Dell-Management/` | Command Update, Configure, etc. |",
        "| `_Misc/` | Non-Dell packages (e.g. Chrome deb) |",
        "| `_incoming/` | Drop new Dell downloads here, run `_sort_factory_docs.py` |",
        "",
        "## File counts",
        "",
    ]
    for folder in sorted(counts):
        lines.append(f"- `{folder}/`: {counts[folder]} files")

    lines.extend([
        "",
        "## Ingest new downloads",
        "",
        "```bash",
        "cp ~/Downloads/* ~/Documents/IndianaDell/FactoryDocs/_incoming/",
        "python3 ~/Documents/IndianaDell/FactoryDocs/_sort_factory_docs.py",
        "```",
    ])
    (ROOT / "README.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Failed removed: {len(failed)}")
    print(f"Duplicates deleted: {len(deleted)}")
    print(f"Moved/sorted: {len(moved)}")
    print(f"Total unique files: {sum(counts.values())}")


if __name__ == "__main__":
    main()