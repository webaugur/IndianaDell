# FactoryDocs Index

Dell T5810 (B1GMB42) support packages — sorted by hardware, then OS.

**Installers stay on disk (gitignored).** Tracked in git: this README, `MANIFEST-pre-crash.txt`, `MISSING-unresolved.txt`, `LOCAL-INVENTORY.txt`.

## Layout

| Folder | Contents |
|--------|----------|
| `System-T5810/` | BIOS, chipset, ME, TPM, manuals |
| `GPU/` | AMD FirePro, NVIDIA Quadro/GeForce, RHEL amd packages |
| `Storage/` | Intel RST, PCIe SSD driver |
| `Network/` | Intel Ethernet |
| `Audio/` | Realtek HD audio |
| `Dell-Management/` | Command Update/Configure, STInstaller, Backup |
| `Expansion-Cards/` | Serial / Thunderbolt |
| `System-T5810/WinPE/WinPEDriverPack/` | Expanded WinPE drivers (local clone; gitignored) |
| `_incoming/` | Drop new downloads, then run sort |
| `_cache/` | Dell CatalogPC (gitignored) |

## Ingest from ~/Downloads

```bash
bin/ingest-downloads              # intact PE/ZIP only; largest of duplicates
# or dry-run:
bin/ingest-downloads --dry-run
```

Then packages are sorted via `FactoryDocs/_sort_factory_docs.py`.

## Re-download from Dell catalog

```bash
bin/factorydocs-download-miss --rate 1500k --sleep 8
```

Still-missing: `MISSING-unresolved.txt` (not in live catalog — try package ID / web).

## WinPE drivers (alternative to retired F0XPX CAB)

```bash
bin/fetch-winpe-driverpack
```

Source: https://github.com/adamaayala/WinPEDriverPack
