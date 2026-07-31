# Chapter 16 — QEMU

QEMU is the core emulation and virtualization engine used throughout the IndianaDell / DragonSDR lab. On Tower5810 it provides the full range of system emulation targets, KVM-accelerated guests, and the shared-library builds required by Velxio / picsimlab for ESP32 development.

The complete upstream documentation lives in the QEMU source tree under `docs/`. This chapter gives a high-level map of that documentation so you can quickly locate the relevant sections.

## Sub-chapters (QEMU docs tree)

### About

High-level information about QEMU itself:

- Supported build platforms and minimum requirements
- Emulation capabilities and architecture coverage
- Deprecated and removed features
- License and contribution overview

### Devel

Developer and internals documentation (most relevant when working on QEMU itself or debugging deep issues):

- Build system, Kconfig, and module architecture
- TCG (Tiny Code Generator) internals and plugins
- QAPI/QOM code generation, memory model, RCU, atomics
- Block layer, migration, multi-threaded TCG, iothreads
- Secure coding practices, style guide, patch submission process
- Tracing, replay, and record/replay infrastructure

### Interop

Interoperability specifications and external interfaces:

- QEMU Machine Protocol (QMP)
- Guest agent protocol
- Block replication, COLO (COarse-grained LOck-stepping) fault tolerance
- NVDIMM, memory hotplug, PCI expander bridges, SR-IOV, etc.

### Specs

Hardware and firmware specifications that QEMU emulates or interacts with:

- ACPI, SMBIOS, device tree fragments
- Virtio, vhost, and paravirtualized device specifications
- Firmware and boot interface details

## Building QEMU on Tower5810

The DragonSDR build script `tools/emulators/qemu-lcgamboa/build-all.sh` produces both:

- The special Velxio/ESP32-compatible shared libraries (`libqemu-xtensa.so`, `libqemu-riscv32.so`)
- Full-featured shared libraries for all other architectures with PipeWire, KVM, virglrenderer, Spice, vhost, and modern storage/networking support enabled by default.

See the script and its pinned commit for the exact feature set.

## Further reading

For the absolute latest and most detailed information, always consult the `docs/` directory inside the QEMU source tree you are building. The structure described above is stable across recent QEMU releases.