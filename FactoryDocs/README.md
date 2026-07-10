# FactoryDocs Index

Dell T5810 (B1GMB42) support packages — sorted by hardware, then OS.

**GitHub:** Archived in https://github.com/webaugur/IndianaDell (private). Installers over 100 MB use Git LFS.

## Recovery status (post-crash)

| Metric | Before crash | Now |
|--------|--------------|-----|
| Sorted packages | **101** | **19** |
| GPU drivers (FirePro/Quadro) | Yes | **Missing** |
| PERC H710 driver/firmware | Yes | **Missing** |
| Audio / Input drivers | Yes | **Missing** |
| Win7/10/WinPE CAB packs | Yes | **Missing** |
| SSD/HDD firmware updaters | Yes | **Missing** |

Full pre-crash file list: **`MANIFEST-pre-crash.txt`** (91 items flagged `MISS`).

## Layout

| Folder | Contents |
|--------|----------|
| `System-T5810/` | BIOS, chipset, ME, TPM, manuals |
| `GPU/` | AMD FirePro, NVIDIA Quadro/GeForce (**empty — re-download**) |
| `Storage/` | PERC H710, Intel RST, SSD/HDD firmware |
| `_incoming/perc-crossflash*.zip` | Optional local drop for Fohdeesha PERC IT flash (see `bin/setup-perc-ventoy`) |
| `_incoming/*H710*.rom` or `scripts/perc/firmware/DELLH710.ROM` | Optional stock Dell H710 ROM bundled into FreeDOS image on next `bin/setup-perc-ventoy` |
| `Network/` | Intel Ethernet |
| `Dell-Management/` | Command Update, Configure, etc. |
| `Expansion-Cards/` | Serial, Thunderbolt docs |
| `_Misc/` | Non-Dell packages |
| `_incoming/` | Drop new Dell downloads here |

## File counts (current)

- `System-T5810/`: 10 files
- `Network/`: 2 files
- `Storage/`: 2 files
- `Dell-Management/`: 2 files
- `Expansion-Cards/`: 2 files
- `_Misc/`: 1 file

## Ingest new downloads

```bash
cp ~/Downloads/* ~/Documents/IndianaDell/FactoryDocs/_incoming/
python3 ~/Documents/IndianaDell/FactoryDocs/_sort_factory_docs.py
```

Priority re-downloads from [Dell T5810 drivers page](https://www.dell.com/support/home/en-us/product-support/product/precision-t5810-workstation/drivers):

1. `GPU/AMD-FirePro/Windows/` — Video_Driver_C5FPW (W5000/W5100)
2. `Storage/RAID-Controller-PERC/Windows/` — PERC H710 driver
3. `System-T5810/Windows-10/` — T5810-win10 CAB
4. `Audio/Windows/` — Audio_Driver_5P33P
5. `Dell-Management/Windows/` — Command Configure, Monitor, STInstaller