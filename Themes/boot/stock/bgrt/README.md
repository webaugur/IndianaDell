# Stock theme: BGRT

**File:** `bgrt.plymouth`  
**Module:** `two-step`  
**ImageDir:** points at `../spinner/` (shared animation + watermark)

Key settings:

- `UseFirmwareBackground=true` — show UEFI OEM logo (Dell)
- `DialogClearsFirmwareBackground=false` — keep firmware image visible under dialog
- `WatermarkVerticalAlignment=0.96` — Ubuntu logo at bottom edge

This is the theme `update-alternatives` selects as `default.plymouth` on a stock Ubuntu 26.04 install with BGRT support.