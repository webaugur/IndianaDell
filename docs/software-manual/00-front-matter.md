---
title: "B1GMB42 Software Manual"
author: "IndianaDell workspace"
date: "2026-09-04"
header-includes:
  - \setlength{\parskip}{0.4em}
---

# B1GMB42 Software Manual

**Machine:** Dell Precision Tower 5810 (B1GMB42)  
**Hostname:** Tower5810  
**OS:** Ubuntu 26.04 LTS (resolute)  
**Workspace:** `~/Documents/IndianaDell`

**Companion hardware manual:** `B1GMB42-slot-port-inventory.md` (slots, GPUs, storage, PERC, ports, lab USB dock)  
**Lab USB dock (WCH + CS202 audio + Genesys microSD):** hardware manual USB section + `docs/usb-wch-cs202-dock.md`  
**Lab host Thumper (NVIDIA GPUs, power/clock locks):** `docs/thumper-gpu.md`  
**Lab host Thumper (ZFS / disks / boot reconstruction):** `docs/thumper-storage.md`

This manual documents every **host-facing install** the IndianaDell workspace provides: apt packages, rustup, Python venvs, built tools, Flatpak apps, GNOME preferences, Plymouth themes, optional GPU/ROCm tooling, ZFS recovery, Ventoy live persistence, and GitHub sync. Each chapter covers one topic using the same structure:

1. What gets installed
2. How it is installed
3. How to verify
4. How to customize
5. What `bin/rebuild-machine` does and does not do

**Build PDFs:** `bin/build-all-docs` (all manuals) or `bin/build-software-manual` (this book only).

**Quick reference:** `docs/features-available.md` (cheat sheet, not a replacement for this manual).

**Chapter index (this manual):**
- 00 Front matter
- 01 Introduction
- 02 Rebuild and recovery
- 03 Post-rebuild checklist
- 04 Development
- 05 Themes
- 06 GPU and display
- 07 GNOME session
- 08 GNU Radio / SDR
- 09 Ham radio
- 10 HackRF Mayhem
- 11 Flatpak apps
- 12 Machine utilities
- 13 Factory docs
- 14 Gaps and limits
- 15 Ventoy live session
- 16 QEMU
- Appendix A — Bin launchers
- Appendix B — Apt packages

**GitHub:** https://github.com/webaugur/IndianaDell (private)

**Supersedes:** flat `B1GMB42-software-inventory.md` (now a stub with links here).