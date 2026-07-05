# Chapter 13 — FactoryDocs (Workspace Archive)

## What gets installed

**Nothing on the Linux host automatically.** FactoryDocs is a sorted archive of Dell T5810 vendor support packages for Windows recovery, firmware, and reference — stored only in the workspace.

| Metric | Pre-crash | Current |
|--------|-----------|---------|
| Sorted packages | 101 | **19** |
| GPU drivers (FirePro/Quadro) | Yes | **Missing** |
| PERC H710 driver/firmware | Yes | **Missing** |
| Audio / input drivers | Yes | **Missing** |
| Win7/10/WinPE CAB packs | Yes | **Missing** |

Full pre-crash file list: `FactoryDocs/MANIFEST-pre-crash.txt` (91 items flagged `MISS`).

## Layout

| Folder | Contents |
|--------|----------|
| `System-T5810/` | BIOS, chipset, ME, TPM, manuals |
| `GPU/` | AMD FirePro, NVIDIA (**empty — re-download**) |
| `Storage/` | PERC H710, Intel RST, SSD/HDD firmware |
| `Network/` | Intel Ethernet |
| `Dell-Management/` | Command Update, Configure |
| `Expansion-Cards/` | Serial, Thunderbolt docs |
| `_Misc/` | Non-Dell packages |
| `_incoming/` | Drop new Dell downloads here |

## How it is installed

**Ingest new downloads:**

```bash
cp ~/Downloads/* ~/Documents/IndianaDell/FactoryDocs/_incoming/
python3 ~/Documents/IndianaDell/FactoryDocs/_sort_factory_docs.py
```

**Priority re-downloads** from [Dell T5810 drivers](https://www.dell.com/support/home/en-us/product-support/product/precision-t5810-workstation/drivers):

1. `GPU/AMD-FirePro/Windows/` — Video_Driver_C5FPW (W5000/W5100)
2. `Storage/RAID-Controller-PERC/Windows/` — PERC H710
3. `System-T5810/Windows-10/` — T5810-win10 CAB
4. `Audio/Windows/` — Audio_Driver_5P33P
5. `Dell-Management/Windows/` — Command Configure, Monitor

Windows installs use Dell CAB/EXE packages from these folders — not apt.

## How to verify

```bash
find FactoryDocs -type f ! -path '*/_incoming/*' | wc -l
cat FactoryDocs/README.md
grep MISS FactoryDocs/MANIFEST-pre-crash.txt | wc -l
```

## How to customize

- `_sort_factory_docs.py` dedupes and sorts by hardware category
- Cross-reference hardware manual: `B1GMB42-slot-port-inventory.md` for what hardware needs drivers

## What rebuild does / does not do

| Does | Does not |
|------|----------|
| Nothing | Copy FactoryDocs to system paths |
| | Install Windows drivers |
| | Download missing CABs |

FactoryDocs recovery is a **manual** ongoing task (Chapter 3 item 7).