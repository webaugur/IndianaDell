#!/usr/bin/env python3
"""Sample Thumper GPU/RAPL as fast as NVML returns; log only deviations.

Idle envelope (2026-08-21 overnight): P8, clocks 139/405, 9.5–16 W, 33–35 °C,
reason idle, no HW brake. CUDA load is a deviation, not an error.

Errors (UDP + CSV): HW power brake / HW slow / HW thermal, GPU ≥ 220 W
(near the 233 W trip), ≥ 80 W drop while SM still high, GPU ≥ 90 °C, NVML fail.
"""
from __future__ import annotations

import argparse
import ctypes
import json
import os
import signal
import socket
import sys
import time
from dataclasses import dataclass
from pathlib import Path

NVML_SUCCESS = 0
NVML_TEMPERATURE_GPU = 0
NVML_CLOCK_SM = 1
NVML_CLOCK_MEM = 2

REASON_IDLE = 0x1
REASON_SW_POWER = 0x4
REASON_HW_SLOW = 0x8
REASON_HW_THERM = 0x40
REASON_HW_BRAKE = 0x80

RAPL_PATHS = {
    "pkg0": "/sys/class/powercap/intel-rapl:0/energy_uj",
    "pkg1": "/sys/class/powercap/intel-rapl:1/energy_uj",
    "dram0": "/sys/class/powercap/intel-rapl:0:1/energy_uj",
    "dram1": "/sys/class/powercap/intel-rapl:1:1/energy_uj",
}

HEADER = (
    "kind,why,ts_ns,gpu_mw,gpu_temp_c,gpu_util,mem_util,vram_mb,sm_mhz,mem_mhz,pstate,"
    "clk_reasons_hex,hw_brake,hw_slow,hw_therm,sw_pwr,idle,"
    "rapl_pkg_w,rapl_dram_w,cpu0_mhz\n"
)

IDLE_MW = 20_000
NEAR_TRIP_MW = 220_000
DROP_MW = 80_000
HOT_C = 90
RAPL_HIGH_W = 100.0
SM_JUMP = 100


class NvmlError(RuntimeError):
    pass


class Nvml:
    def __init__(self) -> None:
        self.ml = ctypes.CDLL("libnvidia-ml.so.1")
        self.ml.nvmlInit_v2.restype = ctypes.c_int
        rc = self.ml.nvmlInit_v2()
        if rc != NVML_SUCCESS:
            raise NvmlError(f"nvmlInit_v2 rc={rc}")
        self.h = ctypes.c_void_p()
        self.ml.nvmlDeviceGetHandleByIndex_v2.argtypes = [
            ctypes.c_uint,
            ctypes.POINTER(ctypes.c_void_p),
        ]
        self.ml.nvmlDeviceGetHandleByIndex_v2.restype = ctypes.c_int
        rc = self.ml.nvmlDeviceGetHandleByIndex_v2(0, ctypes.byref(self.h))
        if rc != NVML_SUCCESS:
            raise NvmlError(f"nvmlDeviceGetHandleByIndex_v2 rc={rc}")

    def u32(self, name: str, extra: int | None = None) -> int:
        v = ctypes.c_uint()
        fn = getattr(self.ml, name)
        if extra is None:
            fn.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_uint)]
            rc = fn(self.h, ctypes.byref(v))
        else:
            fn.argtypes = [
                ctypes.c_void_p,
                ctypes.c_int,
                ctypes.POINTER(ctypes.c_uint),
            ]
            rc = fn(self.h, extra, ctypes.byref(v))
        if rc != NVML_SUCCESS:
            raise NvmlError(f"{name} rc={rc}")
        return int(v.value)

    def reasons(self) -> int:
        v = ctypes.c_ulonglong()
        fn = self.ml.nvmlDeviceGetCurrentClocksEventReasons
        fn.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_ulonglong)]
        fn.restype = ctypes.c_int
        rc = fn(self.h, ctypes.byref(v))
        if rc != NVML_SUCCESS:
            raise NvmlError(f"clocksEventReasons rc={rc}")
        return int(v.value)

    def util(self) -> tuple[int, int]:
        class Util(ctypes.Structure):
            _fields_ = [("gpu", ctypes.c_uint), ("memory", ctypes.c_uint)]

        u = Util()
        fn = self.ml.nvmlDeviceGetUtilizationRates
        fn.argtypes = [ctypes.c_void_p, ctypes.POINTER(Util)]
        fn.restype = ctypes.c_int
        rc = fn(self.h, ctypes.byref(u))
        if rc != NVML_SUCCESS:
            raise NvmlError(f"util rc={rc}")
        return int(u.gpu), int(u.memory)

    def vram_mb(self) -> int:
        class Mem(ctypes.Structure):
            _fields_ = [
                ("total", ctypes.c_ulonglong),
                ("free", ctypes.c_ulonglong),
                ("used", ctypes.c_ulonglong),
            ]

        m = Mem()
        fn = self.ml.nvmlDeviceGetMemoryInfo
        fn.argtypes = [ctypes.c_void_p, ctypes.POINTER(Mem)]
        fn.restype = ctypes.c_int
        rc = fn(self.h, ctypes.byref(m))
        if rc != NVML_SUCCESS:
            raise NvmlError(f"mem rc={rc}")
        return int(m.used // (1024 * 1024))


def read_uj(path: str) -> int | None:
    try:
        with open(path, encoding="utf-8") as f:
            return int(f.read().strip())
    except OSError:
        return None


def cpu0_mhz() -> str:
    p = "/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq"
    try:
        with open(p, encoding="utf-8") as f:
            return f"{int(f.read().strip()) / 1000:.0f}"
    except OSError:
        return ""


def rapl_snapshot() -> dict[str, int | None]:
    return {k: read_uj(p) for k, p in RAPL_PATHS.items()}


def rapl_watts(
    prev: dict[str, int | None], now: dict[str, int | None], dt_s: float
) -> tuple[float | None, float | None]:
    if dt_s < 0.001:
        return None, None

    def pair(a: str, b: str) -> float | None:
        total_prev = 0
        total_now = 0
        n = 0
        for key in (a, b):
            if prev.get(key) is None or now.get(key) is None:
                continue
            total_prev += int(prev[key])
            total_now += int(now[key])
            n += 1
        if n == 0:
            return None
        du = total_now - total_prev
        if du < 0:
            return None
        return (du / 1e6) / dt_s

    return pair("pkg0", "pkg1"), pair("dram0", "dram1")


def pwr_band(mw: int) -> str:
    if mw < IDLE_MW + 10_000:
        return "idle"
    if mw < 100_000:
        return "load"
    if mw < NEAR_TRIP_MW:
        return "heavy"
    return "near_trip"


@dataclass
class Sample:
    ts_ns: int
    gpu_mw: int
    temp: int
    gpu_u: int
    mem_u: int
    vram: int
    sm: int
    memc: int
    pstate: int
    reasons: int
    pkg_w: float | None
    dram_w: float | None
    cpu_mhz: str

    @property
    def hw_brake(self) -> bool:
        return bool(self.reasons & REASON_HW_BRAKE)

    @property
    def hw_slow(self) -> bool:
        return bool(self.reasons & REASON_HW_SLOW)

    @property
    def hw_therm(self) -> bool:
        return bool(self.reasons & REASON_HW_THERM)

    @property
    def sw_pwr(self) -> bool:
        return bool(self.reasons & REASON_SW_POWER)

    @property
    def idle(self) -> bool:
        return bool(self.reasons & REASON_IDLE)


def classify(s: Sample, prev: Sample | None) -> tuple[str | None, list[str]]:
    err: list[str] = []
    dev: list[str] = []
    if s.hw_brake:
        err.append("hw_brake")
    if s.hw_slow:
        err.append("hw_slow")
    if s.hw_therm:
        err.append("hw_therm")
    if s.gpu_mw >= NEAR_TRIP_MW:
        err.append(f"gpu_mw={s.gpu_mw}")
    if s.temp >= HOT_C:
        err.append(f"temp_c={s.temp}")
    if (
        prev is not None
        and prev.sm >= 1000
        and s.sm >= 800
        and prev.gpu_mw - s.gpu_mw >= DROP_MW
    ):
        err.append(f"gpu_mw_drop {prev.gpu_mw}->{s.gpu_mw}")

    if prev is None:
        return ("error" if err else None), err

    if s.pstate != prev.pstate:
        dev.append(f"pstate {prev.pstate}->{s.pstate}")
    if s.reasons != prev.reasons:
        dev.append(f"reasons 0x{prev.reasons:x}->0x{s.reasons:x}")
    if pwr_band(s.gpu_mw) != pwr_band(prev.gpu_mw):
        dev.append(f"pwr_band {pwr_band(prev.gpu_mw)}->{pwr_band(s.gpu_mw)}")
    if abs(s.sm - prev.sm) >= SM_JUMP:
        dev.append(f"sm {prev.sm}->{s.sm}")
    prev_rapl = prev.pkg_w if prev.pkg_w is not None else 0.0
    if s.pkg_w is not None and s.pkg_w >= RAPL_HIGH_W and prev_rapl < RAPL_HIGH_W:
        dev.append(f"rapl_pkg_w={s.pkg_w:.1f}")
    if s.sw_pwr and not prev.sw_pwr:
        dev.append("sw_pwr")

    if err:
        return "error", err + dev
    if dev:
        return "dev", dev
    return None, []


def sample_line(kind: str, why: list[str], s: Sample) -> str:
    pkg = "" if s.pkg_w is None else f"{s.pkg_w:.3f}"
    dram = "" if s.dram_w is None else f"{s.dram_w:.3f}"
    return (
        f"{kind},{'|'.join(why)},{s.ts_ns},{s.gpu_mw},{s.temp},{s.gpu_u},{s.mem_u},"
        f"{s.vram},{s.sm},{s.memc},{s.pstate},0x{s.reasons:x},"
        f"{int(s.hw_brake)},{int(s.hw_slow)},{int(s.hw_therm)},{int(s.sw_pwr)},"
        f"{int(s.idle)},{pkg},{dram},{s.cpu_mhz}\n"
    )


def sample_json(kind: str, why: list[str], s: Sample) -> bytes:
    payload = {
        "v": 1,
        "kind": kind,
        "why": why,
        "ts_ns": s.ts_ns,
        "gpu_mw": s.gpu_mw,
        "gpu_temp_c": s.temp,
        "gpu_util": s.gpu_u,
        "vram_mb": s.vram,
        "sm_mhz": s.sm,
        "mem_mhz": s.memc,
        "pstate": s.pstate,
        "clk_reasons_hex": f"0x{s.reasons:x}",
        "rapl_pkg_w": s.pkg_w,
        "rapl_dram_w": s.dram_w,
    }
    return (json.dumps(payload, separators=(",", ":")) + "\n").encode("utf-8")


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Log Thumper GPU/RAPL deviations only")
    p.add_argument(
        "--log",
        default="/home/user/logs/thumper-rail-events.csv",
        help="CSV of deviations/errors only",
    )
    p.add_argument("--udp", default="", help="host:port JSON events (e.g. 10.0.0.113:9370)")
    p.add_argument("--no-rapl", action="store_true")
    return p.parse_args()


def main() -> int:
    args = parse_args()
    stop = False

    def _stop(_signum: int, _frame: object) -> None:
        nonlocal stop
        stop = True

    signal.signal(signal.SIGTERM, _stop)
    signal.signal(signal.SIGINT, _stop)

    try:
        nv = Nvml()
    except (OSError, NvmlError) as e:
        print(f"thumper-rail-watch: NVML init failed: {e}", file=sys.stderr)
        return 1

    log_path = Path(args.log)
    try:
        log_path.parent.mkdir(parents=True, exist_ok=True)
    except OSError as e:
        print(f"thumper-rail-watch: cannot mkdir {log_path.parent}: {e}", file=sys.stderr)
        return 1

    sock: socket.socket | None = None
    dest: tuple[str, int] | None = None
    if args.udp:
        host, _, port_s = args.udp.rpartition(":")
        if not host or not port_s:
            print("thumper-rail-watch: --udp needs host:port", file=sys.stderr)
            return 1
        dest = (host, int(port_s))
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    new_file = not log_path.exists() or log_path.stat().st_size == 0
    try:
        logf = open(log_path, "a", encoding="utf-8", buffering=1)
    except OSError as e:
        print(f"thumper-rail-watch: cannot open {log_path}: {e}", file=sys.stderr)
        return 1
    if new_file:
        logf.write(HEADER)
        logf.flush()
        os.fsync(logf.fileno())

    prev_rapl = None if args.no_rapl else rapl_snapshot()
    prev_ns = time.monotonic_ns()
    prev: Sample | None = None
    print(
        f"thumper-rail-watch: deviations-only log={log_path} udp={args.udp or 'off'} "
        f"pid={os.getpid()}",
        flush=True,
    )

    while not stop:
        try:
            gpu_mw = nv.u32("nvmlDeviceGetPowerUsage")
            temp = nv.u32("nvmlDeviceGetTemperature", NVML_TEMPERATURE_GPU)
            gpu_u, mem_u = nv.util()
            vram = nv.vram_mb()
            sm = nv.u32("nvmlDeviceGetClockInfo", NVML_CLOCK_SM)
            memc = nv.u32("nvmlDeviceGetClockInfo", NVML_CLOCK_MEM)
            pstate = nv.u32("nvmlDeviceGetPerformanceState")
            reasons = nv.reasons()
        except NvmlError as e:
            print(f"thumper-rail-watch: NVML read failed: {e}", file=sys.stderr)
            fail = {
                "v": 1,
                "kind": "error",
                "why": [f"nvml:{e}"],
                "ts_ns": time.time_ns(),
            }
            if sock is not None and dest is not None:
                try:
                    sock.sendto(
                        (json.dumps(fail, separators=(",", ":")) + "\n").encode(), dest
                    )
                except OSError:
                    pass
            return 1

        pkg_w, dram_w = None, None
        now_ns = time.monotonic_ns()
        if not args.no_rapl:
            now_rapl = rapl_snapshot()
            now_ns = time.monotonic_ns()
            dt_s = (now_ns - prev_ns) / 1e9
            pkg_w, dram_w = rapl_watts(prev_rapl or {}, now_rapl, dt_s)
            prev_rapl = now_rapl
        prev_ns = now_ns

        s = Sample(
            ts_ns=time.time_ns(),
            gpu_mw=gpu_mw,
            temp=temp,
            gpu_u=gpu_u,
            mem_u=mem_u,
            vram=vram,
            sm=sm,
            memc=memc,
            pstate=pstate,
            reasons=reasons,
            pkg_w=pkg_w,
            dram_w=dram_w,
            cpu_mhz=cpu0_mhz(),
        )
        kind, why = classify(s, prev)
        prev = s
        if kind is None:
            continue
        line = sample_line(kind, why, s)
        try:
            logf.write(line)
            logf.flush()
            if kind == "error":
                os.fsync(logf.fileno())
        except OSError as e:
            print(f"thumper-rail-watch: write failed: {e}", file=sys.stderr)
            return 1
        if sock is not None and dest is not None:
            try:
                sock.sendto(sample_json(kind, why, s), dest)
            except OSError:
                pass

    try:
        logf.flush()
        os.fsync(logf.fileno())
    except OSError:
        pass
    logf.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
