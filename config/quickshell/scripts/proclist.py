#!/usr/bin/env python3
"""Per-process CPU, memory and I/O, for the dashboard's process list.

Emits one JSON array per sample on stdout, one line each:

    [{"pid":123,"name":"firefox","cpu":4.2,"mem":3.1,"rss":512000,"io":10240}, ...]

`cpu` is a true delta between samples rather than the average-since-start that
`ps` reports, so it reflects what a process is doing *now*.

`io` is bytes/s from /proc/PID/io, which counts every read and write the
process makes — including sockets. Per-process *network* alone is not
obtainable without root (nethogs) or eBPF, so this is the honest superset.
"""

import json
import os
import sys
import time

INTERVAL = 3.0
FIRST_INTERVAL = 0.4
TOP_N = 14
CLK_TCK = os.sysconf("SC_CLK_TCK")
PAGE_KB = os.sysconf("SC_PAGE_SIZE") // 1024


def total_mem_kb():
    with open("/proc/meminfo") as fh:
        for line in fh:
            if line.startswith("MemTotal:"):
                return int(line.split()[1])
    return 0


def sample():
    """{pid: (jiffies, io_bytes, rss_kb, name)}"""
    out = {}
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        try:
            with open(f"/proc/{pid}/stat") as fh:
                data = fh.read()
            # comm can contain spaces and parens; everything after the last
            # ')' is positional, so split there rather than on whitespace.
            rparen = data.rindex(")")
            name = data[data.index("(") + 1:rparen]
            fields = data[rparen + 2:].split()
            utime, stime = int(fields[11]), int(fields[12])
            rss_kb = int(fields[21]) * PAGE_KB

            io_bytes = 0
            try:
                with open(f"/proc/{pid}/io") as fh:
                    for line in fh:
                        if line.startswith(("rchar:", "wchar:")):
                            io_bytes += int(line.split()[1])
            except (PermissionError, FileNotFoundError):
                pass

            out[int(pid)] = (utime + stime, io_bytes, rss_kb, name)
        except (FileNotFoundError, ProcessLookupError, ValueError, IndexError):
            # Processes disappear mid-walk; that is normal, not an error.
            continue
    return out


def main():
    mem_total = total_mem_kb() or 1
    ncpu = os.cpu_count() or 1
    prev = sample()
    prev_t = time.monotonic()

    # A delta needs two samples, so there is always some wait before the first
    # row can be emitted. Make that first wait short so the list is populated
    # almost immediately, then settle to the normal interval.
    wait = FIRST_INTERVAL

    while True:
        time.sleep(wait)
        wait = INTERVAL
        cur = sample()
        now = time.monotonic()
        dt = max(0.001, now - prev_t)

        rows = []
        for pid, (jiff, io_b, rss, name) in cur.items():
            if pid not in prev:
                continue
            p_jiff, p_io, _, _ = prev[pid]
            # Percent of a single core, the same convention top uses.
            cpu = (jiff - p_jiff) / CLK_TCK / dt * 100.0
            io = max(0, io_b - p_io) / dt
            rows.append({
                "pid": pid,
                "name": name,
                "cpu": round(max(0.0, cpu), 1),
                "mem": round(rss * 100.0 / mem_total, 1),
                "rss": rss,
                "io": int(io),
            })

        rows.sort(key=lambda r: (-r["cpu"], -r["rss"]))
        sys.stdout.write(json.dumps(rows[:TOP_N]) + "\n")
        sys.stdout.flush()

        prev, prev_t = cur, now


if __name__ == "__main__":
    try:
        main()
    except (BrokenPipeError, KeyboardInterrupt):
        pass
