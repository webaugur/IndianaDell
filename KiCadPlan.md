# KiCad 10 — IndianaDell implementation plan

**Status:** implemented on Tower5810 (2026-09-04) — KiCad **10.0.6** + ngspice/gerbv + **tscircuit** (`tsci`) in rebuild  
**Owner:** IndianaDell (workstation restore) — **not** DragonSDR  
**Host audited:** Tower5810 / Ubuntu 26.04 (“resolute”), 2026-08-11  
**Goal:** Complete, reproducible **KiCad 10** install with all useful options; keep it on rebuild.

---

## 0. Agent constraints

- Follow `AGENTS.md` (no PRs unless user asks; prefer commit + push summary).
- Do **not** add KiCad to DragonSDR `install-suite` / `package-lists.sh`.
- Prefer apt + official KiCad 10.0 PPA over Flatpak/Snap/AppImage.
- Ask before destructive apt purges; upgrades and new installs are fine after confirming this plan.

---

## 1. Current state (audit findings)

### Installed today (good)

| Package | Version | Notes |
|---------|---------|--------|
| `kicad` | **10.0.4~ubuntu26.04.1** | `/usr/bin/kicad`, `kicad-cli`, `pcbnew`, `eeschema`, `gerbview`, `pcb_calculator`, `pl_editor`, `bitmap2component` |
| `kicad-libraries` | 10.0.4 | meta → symbols / footprints / 3D / templates |
| `kicad-symbols` | 10.0.4 | ~25 MB |
| `kicad-footprints` | 10.0.4 | ~92 MB |
| `kicad-packages3d` | 10.0.4 | **~1.2 GB** present |
| `kicad-templates` | 10.0.4 | |
| `kicad-demos` | 10.0.4 | ~151 MB |
| `kicad-dbg` | 10.0.4 | debug symbols |
| `kicad-doc-{en,de,fr,es,it,ja,pl,ru,zh,ca}` | 10.0.4 | |
| `kicad-doc-id` | **9.0.8+dfsg-1** | version skew (universe only) |
| `kicad-gruvbox-theme` | 1.1-2 | extra theme |

- **PPA already configured:** `/etc/apt/sources.list.d/kicad-ubuntu-kicad-10_0-releases-resolute.sources` → `ppa:kicad/kicad-10.0-releases`
- **Python API:** `python3 -c 'import pcbnew; print(pcbnew.Version())'` → `10.0.4`
- **OCCT** libs present (3D viewer support)

### Gaps

| Gap | Severity | Action |
|-----|----------|--------|
| Core stuck at **10.0.4**; PPA candidate **10.0.6** | Medium | Upgrade `kicad*` from PPA |
| **`ngspice` missing** | High for simulation | Install (Eeschema SPICE) |
| **`gerbv` missing** | Low | Optional; `gerbview` already covers lab Gerbers |
| **`kicad-doc-id` on 9.0.8** | Cosmetic | Leave or drop until PPA ships 10.x |
| **Not in `APT_CORE` / rebuild** | **High** | Fresh `rebuild-machine` will **not** restore KiCad |

Evidence of install-but-not-rebuild: packages appear in `apt-full-manifest.txt` (dpkg dump) but **not** in `scripts/rebuild/package-lists.sh`.

---

## 2. Target end state

1. KiCad **10.0.6** (or latest `10.0.*` from `kicad-10.0-releases` PPA).
2. Full useful package set installed and listed in IndianaDell rebuild sources of truth.
3. `ngspice` installed for schematic simulation.
4. Optional `gerbv` installed (recommended yes for “all useful options”).
5. `bin/fix-indianadell.sh --fix` (or equivalent) reports KiCad OK.
6. Docs updated: software manual appendix / features note as needed.
7. PPA ensured idempotently on rebuild (not only on this host by accident).

---

## 3. Implementation steps (do in order)

### Step A — Add `APT_KICAD` to package lists

**File:** `scripts/rebuild/package-lists.sh`

Add a dedicated array (do **not** dump the huge 3D set into a comment-free blob without the meta package):

```bash
# KiCad 10 (EDA) — optional but installed by default on workstation rebuild.
# Requires PPA: ppa:kicad/kicad-10.0-releases (see ensure_kicad_ppa in rebuild-machine.sh).
# Opt out: SKIP_KICAD=1
APT_KICAD=(
  kicad
  kicad-libraries          # pulls symbols, footprints, packages3d, templates
  kicad-symbols
  kicad-footprints
  kicad-packages3d         # large (~1GB+); keep — “useful options” includes 3D
  kicad-templates
  kicad-demos
  kicad-dbg
  kicad-doc-en
  kicad-doc-de
  kicad-doc-fr
  kicad-doc-es
  kicad-doc-it
  kicad-doc-ja
  kicad-doc-pl
  kicad-doc-ru
  kicad-doc-zh
  kicad-doc-ca
  # kicad-doc-id — skip until PPA has 10.x (universe still on 9.0.8)
  kicad-gruvbox-theme
  ngspice                  # Eeschema / simulation companion
  gerbv                    # standalone Gerber viewer (optional companion; keep for completeness)
)
```

Wire into rebuild the same way DragonSDR does optional defaults:

- Install when `SKIP_KICAD` is unset / not `1`.
- Document `SKIP_KICAD=1` in rebuild help / README / software manual.

### Step B — Ensure KiCad 10 PPA on rebuild

**File:** `scripts/rebuild/rebuild-machine.sh` (or a small helper `scripts/rebuild/ensure-kicad-ppa.sh` sourced by it)

Idempotent logic:

```bash
ensure_kicad_ppa() {
  # Prefer add-apt-repository if present; else write .sources like current host.
  if [[ ! -f /etc/apt/sources.list.d/kicad-ubuntu-kicad-10_0-releases-resolute.sources ]] \
     && [[ ! -f /etc/apt/sources.list.d/kicad-ubuntu-kicad-10_0-releases-*.sources ]]; then
    sudo add-apt-repository -y ppa:kicad/kicad-10.0-releases
  fi
  sudo apt-get update -qq
}
```

Call **before** `apt-get install "${APT_KICAD[@]}"`.

Codename note: this host uses **resolute**; helper should use `lsb_release -cs` / `$VERSION_CODENAME` so rebuilds on future Ubuntu releases still work.

### Step C — Install / upgrade on this host now

```bash
sudo apt-get update
sudo apt-get install -y ngspice gerbv
sudo apt-get install --only-upgrade -y \
  kicad kicad-dbg kicad-demos kicad-libraries \
  kicad-symbols kicad-footprints kicad-packages3d kicad-templates \
  kicad-doc-en kicad-doc-de kicad-doc-fr kicad-doc-es kicad-doc-it \
  kicad-doc-ja kicad-doc-pl kicad-doc-ru kicad-doc-zh kicad-doc-ca
# Expect kicad → 10.0.6~ubuntu26.04.1 (or newer 10.0.x)
```

Do **not** force-upgrade `kicad-doc-id` from universe 9.x onto 10.x stacks if apt conflicts; leave or remove.

### Step D — Verification

Add checks to `bin/fix-indianadell.sh` (or a `check_kicad` helper), soft-or-hard consistent with other workstation apps:

```bash
check_kicad() {
  [[ "${SKIP_KICAD:-0}" == 1 ]] && { echo "SKIP kicad"; return 0; }
  local fail=0
  command -v kicad >/dev/null || { echo "MISS kicad"; fail=1; }
  command -v kicad-cli >/dev/null || { echo "MISS kicad-cli"; fail=1; }
  command -v ngspice >/dev/null || { echo "MISS ngspice"; fail=1; }
  dpkg-query -W -f='${Status}' kicad-packages3d 2>/dev/null | grep -q 'install ok installed' \
    || { echo "MISS kicad-packages3d"; fail=1; }
  # version smoke
  python3 -c 'import pcbnew; v=pcbnew.Version(); print("OK pcbnew", v); assert v.startswith("10.")' \
    || { echo "MISS/FAIL pcbnew python"; fail=1; }
  return "$fail"
}
```

Manual smoke (agent should run):

```bash
kicad-cli version
python3 -c 'import pcbnew; print(pcbnew.Version())'
dpkg-query -W 'kicad*' | sort
command -v ngspice gerbv gerbview
du -sh /usr/share/kicad/{symbols,footprints,3dmodels}
```

### Step E — Docs / manifests

1. Update `docs/software-manual/appendix-b-apt-packages.md` (or equivalent) with `APT_KICAD` + PPA + `SKIP_KICAD=1`.
2. Mention KiCad under EDA / workstation features in `docs/features-available.md` if that file still tracks “what you can do”.
3. After install, refresh manifests via existing rebuild helper (`save_manifests` in `rebuild-machine.sh`) or:

   ```bash
   dpkg-query -W -f='${Package}\n' | sort > apt-full-manifest.txt
   ```

4. Optional one-liner in README rebuild section: KiCad 10 is default-on; `SKIP_KICAD=1` to opt out.

### Step F — Git

Commit on IndianaDell with a message like:

```text
Add KiCad 10 APT_KICAD to rebuild (ngspice, full libs, PPA)

Restore complete KiCad 10 useful options on workstation rebuild; document
SKIP_KICAD=1 and fix verification.
```

Push to `webaugur/IndianaDell` if the user wants remotes updated (do not open a PR unless asked).

---

## 4. Explicit non-goals

- Do not vendor KiCad into DragonSDR.
- Do not install Flatpak/Snap KiCad beside the PPA deb (avoid duplicate versions).
- Do not add Freerouting / pcb2gcode unless the user asks later.
- Do not treat `kicad-doc-id` 9.0.8 mismatch as a blocker.

---

## 5. Acceptance checklist

- [x] `APT_KICAD` exists in `scripts/rebuild/package-lists.sh`
- [x] `rebuild-machine.sh` ensures `ppa:kicad/kicad-10.0-releases` before install
- [x] `SKIP_KICAD=1` honored
- [x] This host: `kicad` **≥ 10.0.6**, `ngspice` present, `kicad-packages3d` present
- [x] `import pcbnew` reports `10.*`
- [x] `fix-indianadell` (or documented check) covers KiCad
- [x] Appendix B / features docs mention KiCad 10 + opt-out
- [x] Changes committed (`0cba668`, `4adbd7f`)
- [x] tscircuit + `@tscircuit/capacity-autorouter` on rebuild (`install-tscircuit.sh`, `SKIP_KICAD=1`)

---

## 6. Quick reference commands

```bash
# Opt out on rebuild
SKIP_KICAD=1 ~/Documents/IndianaDell/bin/rebuild-machine   # or whatever the entrypoint is

# One-shot complete useful set (after PPA present)
sudo apt-get install -y \
  kicad kicad-libraries kicad-symbols kicad-footprints kicad-packages3d \
  kicad-templates kicad-demos kicad-dbg kicad-gruvbox-theme \
  kicad-doc-en kicad-doc-de kicad-doc-fr kicad-doc-es kicad-doc-it \
  kicad-doc-ja kicad-doc-pl kicad-doc-ru kicad-doc-zh kicad-doc-ca \
  ngspice gerbv
```

---

## 7. Follow-on: tscircuit (TypeScript → KiCad)

Implemented. Not a KiCad plugin — npm CLI next to KiCad 10.

| Item | Location |
|------|----------|
| Install | `scripts/rebuild/install-tscircuit.sh` (Phase 2b, `~/.local`) |
| Packages | `tscircuit`, `@tscircuit/capacity-autorouter` (GitHub: [tscircuit-autorouter](https://github.com/tscircuit/tscircuit-autorouter)), `typescript` |
| Launchers | `bin/tsci`, `bin/tscircuit` |
| Export | `tsci export index.tsx -f kicad_sch` (`kicad_pcb`, `kicad_zip`, `kicad-library`) |
| Opt out | `SKIP_KICAD=1` |

Do **not** clone the autorouter git tree into IndianaDell (large bun/dev datasets). npm is the installable form.

## 8. Origin

Stashed from DragonSDR session KiCad audit (plan mode). Live host already had a nearly complete 10.0.4 PPA install; IndianaDell rebuild lists did not own it yet — this plan closes that gap and adds simulation/companion packages.
