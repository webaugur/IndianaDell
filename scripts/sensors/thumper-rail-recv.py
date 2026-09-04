#!/usr/bin/env python3
"""UDP sink for Thumper rail-watch deviation/error JSON.

Logs events (no per-packet fsync). The first error of each local calendar day
pops a GNOME notification on this desk.

  thumper-rail-recv --bind 0.0.0.0:9370 --log ~/logs/thumper-rail-events-udp.csv
"""
from __future__ import annotations

import argparse
import json
import os
import signal
import socket
import subprocess
import sys
import time
from pathlib import Path

HEADER = (
    "kind,why,ts_ns,gpu_mw,gpu_temp_c,gpu_util,vram_mb,sm_mhz,mem_mhz,pstate,"
    "clk_reasons_hex,rapl_pkg_w,rapl_dram_w\n"
)


def notify_desktop(title: str, body: str) -> bool:
    env = os.environ.copy()
    uid = os.getuid()
    bus = f"/run/user/{uid}/bus"
    if os.path.exists(bus):
        env.setdefault("DBUS_SESSION_BUS_ADDRESS", f"unix:path={bus}")
        env.setdefault("XDG_RUNTIME_DIR", f"/run/user/{uid}")
    try:
        r = subprocess.run(
            [
                "/usr/bin/notify-send",
                "-u",
                "critical",
                "-a",
                "thumper-rail-watch",
                "--",
                title,
                body,
            ],
            env=env,
            check=False,
            capture_output=True,
            timeout=5,
        )
        return r.returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        return False


def first_error_today(stamp: Path) -> bool:
    today = time.strftime("%Y-%m-%d")
    try:
        if stamp.read_text(encoding="utf-8").strip() == today:
            return False
    except OSError:
        pass
    try:
        stamp.parent.mkdir(parents=True, exist_ok=True)
        stamp.write_text(today + "\n", encoding="utf-8")
    except OSError as e:
        print(f"thumper-rail-recv: cannot write {stamp}: {e}", file=sys.stderr)
        return True
    return True


def fmt_row(obj: dict) -> str:
    why = obj.get("why") or []
    if isinstance(why, list):
        why_s = "|".join(str(x) for x in why)
    else:
        why_s = str(why)
    pkg = obj.get("rapl_pkg_w")
    dram = obj.get("rapl_dram_w")
    pkg_s = "" if pkg is None else str(pkg)
    dram_s = "" if dram is None else str(dram)
    return (
        f"{obj.get('kind','')},{why_s},{obj.get('ts_ns','')},{obj.get('gpu_mw','')},"
        f"{obj.get('gpu_temp_c','')},{obj.get('gpu_util','')},{obj.get('vram_mb','')},"
        f"{obj.get('sm_mhz','')},{obj.get('mem_mhz','')},{obj.get('pstate','')},"
        f"{obj.get('clk_reasons_hex','')},{pkg_s},{dram_s}\n"
    )


def error_body(obj: dict) -> str:
    why = obj.get("why") or []
    why_s = ", ".join(str(x) for x in why) if isinstance(why, list) else str(why)
    mw = obj.get("gpu_mw")
    temp = obj.get("gpu_temp_c")
    pstate = obj.get("pstate")
    sm = obj.get("sm_mhz")
    bits = [why_s]
    if mw is not None:
        bits.append(f"{mw/1000:.1f} W")
    if temp is not None:
        bits.append(f"{temp} °C")
    if sm is not None:
        bits.append(f"SM {sm} MHz")
    if pstate is not None:
        bits.append(f"P{pstate}")
    bits.append("Further errors today stay in the log only.")
    return " · ".join(bits)


def main() -> int:
    p = argparse.ArgumentParser(description="UDP sink + first daily desktop alert")
    p.add_argument("--bind", default="0.0.0.0:9370")
    p.add_argument(
        "--log",
        default=str(Path.home() / "logs" / "thumper-rail-events-udp.csv"),
    )
    p.add_argument(
        "--notify-stamp",
        default=str(Path.home() / "logs" / "thumper-rail-watch.notify-day"),
    )
    args = p.parse_args()
    host, _, port_s = args.bind.rpartition(":")
    addr = (host or "0.0.0.0", int(port_s))

    log_path = Path(args.log)
    stamp = Path(args.notify_stamp)
    try:
        log_path.parent.mkdir(parents=True, exist_ok=True)
        logf = open(log_path, "a", encoding="utf-8", buffering=1)
    except OSError as e:
        print(f"thumper-rail-recv: cannot open {log_path}: {e}", file=sys.stderr)
        return 1
    if log_path.stat().st_size == 0:
        logf.write(HEADER)
        logf.flush()

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        sock.bind(addr)
    except OSError as e:
        print(f"thumper-rail-recv: bind {addr} failed: {e}", file=sys.stderr)
        return 1
    sock.settimeout(1.0)

    stop = False

    def _stop(_s: int, _f: object) -> None:
        nonlocal stop
        stop = True

    signal.signal(signal.SIGTERM, _stop)
    signal.signal(signal.SIGINT, _stop)
    print(
        f"thumper-rail-recv: bind={addr[0]}:{addr[1]} log={log_path} pid={os.getpid()}",
        flush=True,
    )

    while not stop:
        try:
            data, _src = sock.recvfrom(8192)
        except socket.timeout:
            continue
        except OSError as e:
            print(f"thumper-rail-recv: recv failed: {e}", file=sys.stderr)
            return 1
        text = data.decode("utf-8", errors="replace").strip()
        if not text:
            continue
        try:
            obj = json.loads(text)
        except json.JSONDecodeError:
            print(f"thumper-rail-recv: skip non-JSON {text[:80]!r}", file=sys.stderr)
            continue
        try:
            logf.write(fmt_row(obj))
            if obj.get("kind") == "error":
                logf.flush()
                os.fsync(logf.fileno())
        except OSError as e:
            print(f"thumper-rail-recv: write failed: {e}", file=sys.stderr)
            return 1
        if obj.get("kind") == "error" and first_error_today(stamp):
            title = "Thumper GPU rail"
            if not notify_desktop(title, error_body(obj)):
                print("thumper-rail-recv: notify-send failed", file=sys.stderr)

    try:
        logf.flush()
        os.fsync(logf.fileno())
    except OSError:
        pass
    logf.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
