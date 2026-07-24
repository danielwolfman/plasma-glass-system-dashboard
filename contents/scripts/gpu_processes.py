#!/usr/bin/env python3

import os
import subprocess
import time


def read_text(path):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as stream:
            return stream.read()
    except (FileNotFoundError, PermissionError, ProcessLookupError, OSError):
        return ""


def numeric_value(value):
    token = value.strip().split(maxsplit=1)[0] if value.strip() else "0"
    try:
        return int(token)
    except ValueError:
        return 0


def memory_kib(value):
    parts = value.strip().split()
    amount = numeric_value(value)
    unit = parts[1].lower() if len(parts) > 1 else "bytes"
    if unit == "mib":
        return amount * 1024
    if unit == "kib":
        return amount
    return amount // 1024


def snapshot_intel():
    processes = {}
    try:
        proc_entries = os.scandir("/proc")
    except OSError:
        return processes

    with proc_entries:
        for proc_entry in proc_entries:
            if not proc_entry.name.isdigit():
                continue

            pid = int(proc_entry.name)
            name = read_text(f"/proc/{pid}/comm").strip().replace("\t", " ")
            if not name:
                continue

            clients = {}
            try:
                fdinfo_entries = os.scandir(f"/proc/{pid}/fdinfo")
            except (FileNotFoundError, PermissionError, ProcessLookupError, OSError):
                continue

            with fdinfo_entries:
                for fdinfo_entry in fdinfo_entries:
                    fields = {}
                    contents = read_text(fdinfo_entry.path)
                    if "drm-driver:" not in contents:
                        continue
                    for line in contents.splitlines():
                        key, separator, value = line.partition(":")
                        if separator:
                            fields[key.strip()] = value.strip()

                    if fields.get("drm-driver") != "i915":
                        continue

                    client = fields.get("drm-client-id", fdinfo_entry.name)
                    device = fields.get("drm-pdev", "intel")
                    render = numeric_value(fields.get("drm-engine-render", "0"))
                    resident = sum(
                        memory_kib(value)
                        for key, value in fields.items()
                        if key.startswith("drm-resident-")
                    )
                    client_key = (device, client)
                    previous = clients.get(client_key, (0, 0))
                    clients[client_key] = (max(previous[0], render), max(previous[1], resident))

            if clients:
                processes[pid] = {
                    "name": name,
                    "render": sum(client[0] for client in clients.values()),
                    "memory": sum(client[1] for client in clients.values()),
                }

    return processes


def emit_intel(previous, current, elapsed_ns):
    for pid, values in current.items():
        old_render = previous.get(pid, {}).get("render", values["render"])
        delta = max(0, values["render"] - old_render)
        usage = min(100.0, delta * 100.0 / elapsed_ns) if elapsed_ns > 0 else 0.0
        if usage > 0 or values["memory"] > 0:
            print(f"INTEL\t{pid}\t{values['name']}\t{usage:.3f}\t{values['memory']}")


def emit_nvidia(output):
    columns = {}
    for line in output.splitlines():
        parts = line.split()
        if len(parts) > 2 and parts[0] == "#" and parts[1] == "gpu":
            columns = {name: index for index, name in enumerate(parts[1:])}
            continue
        if not columns or not parts or not parts[0].isdigit():
            continue
        try:
            pid = int(parts[columns["pid"]])
        except (KeyError, IndexError, ValueError):
            continue

        def column_number(name):
            try:
                value = parts[columns[name]]
                return 0 if value == "-" else float(value)
            except (KeyError, IndexError, ValueError):
                return 0

        usage = column_number("sm")
        memory = int(column_number("fb") * 1024)
        process_name = read_text(f"/proc/{pid}/comm").strip().replace("\t", " ")
        if process_name and (usage > 0 or memory > 0):
            print(f"RTX\t{pid}\t{process_name}\t{usage:.3f}\t{memory}")


def main():
    nvidia_process = None
    try:
        nvidia_process = subprocess.Popen(
            ["nvidia-smi", "pmon", "-c", "1", "-s", "mu"],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
        )
    except (FileNotFoundError, OSError):
        pass

    first_start = time.monotonic_ns()
    first = snapshot_intel()
    first_end = time.monotonic_ns()
    time.sleep(0.5)
    second_start = time.monotonic_ns()
    second = snapshot_intel()
    second_end = time.monotonic_ns()
    first_midpoint = (first_start + first_end) // 2
    second_midpoint = (second_start + second_end) // 2
    emit_intel(first, second, second_midpoint - first_midpoint)

    if nvidia_process is not None:
        try:
            stdout, _ = nvidia_process.communicate(timeout=3)
            emit_nvidia(stdout)
        except subprocess.TimeoutExpired:
            nvidia_process.kill()
            nvidia_process.communicate()


if __name__ == "__main__":
    main()
