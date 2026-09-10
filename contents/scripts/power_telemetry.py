#!/usr/bin/env python3

import json
import os
import re
import subprocess
from pathlib import Path


POWER_SUPPLY_ROOT = Path("/sys/class/power_supply")
HWMON_ROOT = Path("/sys/class/hwmon")


def read_text(path):
    try:
        return Path(path).read_text(encoding="utf-8", errors="replace").strip()
    except (FileNotFoundError, PermissionError, OSError):
        return ""


def read_number(path, divisor=1.0):
    try:
        return float(read_text(path)) / divisor
    except ValueError:
        return 0.0


def first_supply(supply_type, online_only=False):
    try:
        supplies = sorted(POWER_SUPPLY_ROOT.iterdir())
    except OSError:
        return None

    for supply in supplies:
        if read_text(supply / "type").lower() != supply_type.lower():
            continue
        if online_only and read_text(supply / "online") != "1":
            continue
        return supply
    return None


def adapter_online():
    try:
        supplies = POWER_SUPPLY_ROOT.iterdir()
    except OSError:
        return False

    for supply in supplies:
        if read_text(supply / "type").lower() not in ("battery", "unknown"):
            if read_text(supply / "online") == "1":
                return True
    return False


def upower_properties(battery_name):
    device = f"/org/freedesktop/UPower/devices/battery_{battery_name}"
    environment = os.environ.copy()
    environment["LC_ALL"] = "C"
    try:
        result = subprocess.run(
            ["upower", "-i", device],
            capture_output=True,
            check=False,
            text=True,
            timeout=1.5,
            env=environment,
        )
    except (FileNotFoundError, OSError, subprocess.TimeoutExpired):
        return {}

    properties = {}
    for line in result.stdout.splitlines():
        key, separator, value = line.strip().partition(":")
        if separator:
            properties[key.strip()] = value.strip()
    return properties


def first_number(value):
    match = re.search(r"[-+]?\d+(?:\.\d+)?", value or "")
    return float(match.group(0)) if match else 0.0


def duration_seconds(value):
    amount = first_number(value)
    lowered = (value or "").lower()
    if "day" in lowered:
        return round(amount * 86400)
    if "hour" in lowered:
        return round(amount * 3600)
    if "minute" in lowered:
        return round(amount * 60)
    if "second" in lowered:
        return round(amount)
    return 0


def fan_speeds():
    fans = []
    try:
        devices = sorted(HWMON_ROOT.iterdir())
    except OSError:
        return fans

    # ThinkPad EC fan readings are preferable to generic ACPI fan states.
    devices.sort(key=lambda path: read_text(path / "name") != "thinkpad")
    for device in devices:
        for fan_input in sorted(device.glob("fan*_input")):
            rpm = round(read_number(fan_input))
            if rpm > 0 or read_text(device / "name") == "thinkpad":
                fans.append(rpm)
        if fans:
            break
    return fans


def battery_telemetry(battery):
    status = read_text(battery / "status").lower().replace(" ", "-") or "unknown"
    energy_now = read_number(battery / "energy_now", 1_000_000)
    energy_full = read_number(battery / "energy_full", 1_000_000)
    energy_design = read_number(battery / "energy_full_design", 1_000_000)
    voltage = read_number(battery / "voltage_now", 1_000_000)
    percentage = read_number(battery / "capacity")
    properties = upower_properties(battery.name)

    state = properties.get("state", status).lower().replace(" ", "-")
    rate = first_number(properties.get("energy-rate", ""))
    if rate <= 0:
        rate = read_number(battery / "power_now", 1_000_000)

    if state == "discharging":
        signed_rate = -abs(rate)
    elif state == "charging":
        signed_rate = abs(rate)
    else:
        signed_rate = 0.0

    time_to_empty = duration_seconds(properties.get("time to empty", ""))
    time_to_full = duration_seconds(properties.get("time to full", ""))
    if time_to_empty <= 0 and signed_rate < 0:
        time_to_empty = round(energy_now / abs(signed_rate) * 3600)
    if time_to_full <= 0 and signed_rate > 0:
        time_to_full = round(max(0.0, energy_full - energy_now) / signed_rate * 3600)

    health = first_number(properties.get("capacity", ""))
    if health <= 0 and energy_design > 0:
        health = energy_full * 100 / energy_design

    return {
        "available": True,
        "battery_name": battery.name,
        "battery_state": state,
        "battery_percent": percentage,
        "battery_energy_wh": energy_now,
        "battery_full_wh": energy_full,
        "battery_design_wh": energy_design,
        "battery_health_percent": health,
        "battery_voltage_v": voltage,
        "battery_flow_w": signed_rate,
        "time_to_empty_s": time_to_empty,
        "time_to_full_s": time_to_full,
    }


def main():
    battery = first_supply("Battery")
    telemetry = battery_telemetry(battery) if battery else {"available": False}
    telemetry["adapter_online"] = adapter_online()

    usb_source = first_supply("USB", online_only=True)
    if usb_source:
        source_voltage = read_number(usb_source / "voltage_now", 1_000_000)
        source_current = read_number(usb_source / "current_now", 1_000_000)
        source_max_voltage = read_number(usb_source / "voltage_max", 1_000_000)
        source_max_current = read_number(usb_source / "current_max", 1_000_000)
    else:
        source_voltage = 0.0
        source_current = 0.0
        source_max_voltage = 0.0
        source_max_current = 0.0
    telemetry["source_voltage_v"] = source_voltage
    telemetry["source_current_a"] = source_current
    telemetry["source_power_w"] = source_voltage * source_current
    telemetry["source_max_voltage_v"] = source_max_voltage
    telemetry["source_max_current_a"] = source_max_current
    telemetry["source_max_power_w"] = source_max_voltage * source_max_current
    telemetry["fans_rpm"] = fan_speeds()

    print(json.dumps(telemetry, separators=(",", ":"), sort_keys=True))


if __name__ == "__main__":
    main()
