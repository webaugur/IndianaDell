---
title: "B1GMB42 Software Manual"
author: "IndianaDell workspace"
date: "2026-07-09"
header-includes:
  - \setlength{\parskip}{0.4em}
---

# B1GMB42 Software Manual

**Machine:** Dell Precision Tower 5810 (B1GMB42)  
**Hostname:** Tower5810  
**OS:** Ubuntu 26.04 LTS (resolute)  
**Workspace:** `~/Documents/IndianaDell`

**Companion hardware manual:** `B1GMB42-slot-port-inventory.md` (slots, GPUs, storage, PERC, ports)

This manual documents every **host-facing install** the IndianaDell workspace provides: apt packages, rustup, Python venvs, built tools, Flatpak apps, GNOME preferences, Plymouth themes, optional GPU/ROCm tooling, ZFS recovery, Ventoy live persistence, and GitHub sync. Each chapter covers one topic using the same structure:

1. What gets installed
2. How it is installed
3. How to verify
4. How to customize
5. What `bin/rebuild-machine` does and does not do

**Build PDFs:** `bin/build-all-docs` (all manuals) or `bin/build-software-manual` (this book only).

**Quick reference:** `docs/features-available.md` (cheat sheet, not a replacement for this manual).

**GitHub:** https://github.com/webaugur/IndianaDell (private)

**Supersedes:** flat `B1GMB42-software-inventory.md` (now a stub with links here).