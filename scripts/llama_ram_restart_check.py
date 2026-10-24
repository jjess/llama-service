#!/usr/bin/env python3
"""llama_ram_restart_check.py - Low-free-RAM restart checker for llama-server@%i
Reads /proc/meminfo, applies hysteresis on available RAM %, and calls
systemctl try-restart for the instance if sustained pressure is detected.
State is stored in RAM_RESTART_STATE_DIR (tmpfs via RuntimeDirectory).
"""
import json
import os
import subprocess
import sys
import time


def die(msg):
    print(f"llama_ram_restart_check: {msg}", flush=True)
    sys.exit(1)


def read_meminfo():
    mem = {}
    try:
        with open("/proc/meminfo", "r") as f:
            for line in f:
                try:
                    key, val = line.split(":", 1)
                    parts = val.strip().split()
                    if parts:
                        mem[key.strip()] = int(parts[0])
                except ValueError:
                    continue
    except OSError as e:
        die(f"cannot read /proc/meminfo: {e}")
    return mem


def get_pct_free(mem):
    total = mem.get("MemTotal")
    avail = mem.get("MemAvailable")
    if avail is not None and total:
        return (avail / total) * 100.0
    free = mem.get("MemFree")
    if free is not None and total:
        return (free / total) * 100.0
    die("cannot compute free memory percentage")


def main():
    if len(sys.argv) < 2:
        die("usage: llama_ram_restart_check.py <preset>")
    preset = sys.argv[1]

    threshold = float(os.environ.get("RAM_RESTART_THRESHOLD", "6"))
    hysteresis_count = int(os.environ.get("RAM_RESTART_HYSTERESIS_COUNT", "3"))
    hysteresis_reset = float(os.environ.get("RAM_RESTART_HYSTERESIS_RESET", "2"))
    state_dir = os.environ.get("RAM_RESTART_STATE_DIR", "/run/llama-service-rmrestart")

    try:
        os.makedirs(state_dir, exist_ok=True)
    except OSError as e:
        die(f"cannot create state dir {state_dir}: {e}")

    state_file = os.path.join(state_dir, f"ram-restart-{preset}.json")

    below_count = 0
    try:
        if os.path.isfile(state_file):
            with open(state_file, "r") as f:
                data = json.load(f)
                below_count = int(data.get("below_count", 0))
    except (OSError, ValueError, json.JSONDecodeError):
        below_count = 0

    mem = read_meminfo()
    pct_free = get_pct_free(mem)
    print(f"preset={preset} pct_free={pct_free:.2f}% threshold={threshold}% below_count={below_count}", flush=True)

    reset_above = threshold + hysteresis_reset
    if pct_free < threshold:
        below_count += 1
        print(f"below threshold: below_count -> {below_count}/{hysteresis_count}", flush=True)
    elif pct_free > reset_above:
        if below_count != 0:
            print(f"above reset threshold ({reset_above:.2f}%): resetting below_count to 0", flush=True)
        below_count = 0

    if below_count >= hysteresis_count:
        unit = f"llama-server@{preset}.service"
        print(f"sustained low RAM ({below_count} >= {hysteresis_count}): triggering systemctl try-restart {unit}", flush=True)
        try:
            res = subprocess.run(["systemctl", "try-restart", unit], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            print(f"systemctl try-restart rc={res.returncode} stdout={res.stdout.decode().strip()} stderr={res.stderr.decode().strip()}", flush=True)
        except FileNotFoundError:
            die("systemctl not found")
        except Exception as e:
            die(f"try-restart failed: {e}")
        below_count = 0

    try:
        data = {"below_count": below_count, "last_ts": int(time.time()), "pct_free": round(pct_free, 3)}
        tmp = state_file + ".tmp"
        with open(tmp, "w") as f:
            json.dump(data, f)
        os.replace(tmp, state_file)
    except OSError as e:
        print(f"warning: cannot write state {state_file}: {e}", flush=True)


if __name__ == "__main__":
    main()
