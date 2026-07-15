# Staging (local preview trees)

Built by:

```bash
Themes/scripts/install-boot-theme.sh --stage-only
Themes/scripts/install-boot-theme.sh --stage-only --animated-dell
# or simply:
bin/themes-preview-boot --animated-dell
```

Contents mirror what would be installed under `/usr/share/plymouth/themes/indianadell/`, but stay in the workspace. **No root, no initramfs, no default theme switch.**

This directory is gitignored except this README. Safe to delete anytime.
