# Glass System Dashboard

A wide, translucent system-monitor widget for KDE Plasma 6, inspired by the
dashboard layout of Plasma System Monitor.

It displays live CPU, memory, NVIDIA and Intel GPU, network, storage, battery,
power-source, and cooling data. Most values come from KDE's `ksystemstats`
sensor backend; device-aware GPU and power telemetry use lightweight bundled
collectors. Values switch to yellow or red at configurable warning and critical
thresholds.

## Features

- CPU load history, frequency, and temperature
- Adaptive ring-gauge map for every logical CPU
- Memory and storage ring gauges
- NVIDIA and Intel GPU utilization, memory, temperature, power, and frequency
- Network download and upload history
- Disk read and write activity
- Battery charge, health, stored energy, signed charge/discharge flow, and time estimate
- USB-C PD contract and advertised source capacity
- ThinkPad fan RPM with dual-fan support
- Ranked CPU, memory, and GPU process lists
- Combined GPU consumers with per-row `RTX` and `INTEL` indicators
- Device-aware hybrid-GPU collection, including processes active on both GPUs
- Configurable outer-background and card opacity
- Optional accent glow
- Configurable warning and critical levels

## Requirements

- KDE Plasma 6
- `ksystemstats`
- `libksysguard`
- Python 3 (for the bundled GPU and power collectors)
- UPower and Linux sysfs power/hardware-monitor interfaces

The sensor identifiers in this version are arranged for a hybrid laptop where
`gpu0` is NVIDIA and `gpu1` is Intel. They can be adjusted in
`contents/ui/main.qml` for other hardware layouts.

## Desktop layout

At widths of 1500 pixels and above, the dashboard uses a compact, horizontal
layout intended to share a screen with the other Glass dashboard: System above,
Codex below. Both default to 1880 × 500 pixels and allow unlimited expansion.
Leave Plasma's screen-edge margins and bottom panel clear when placing them.

Hardware cards fill the first row; processes, power, and a compact CPU core map
fill the second. Below 1500 pixels, cards return to four rows and full core gauges.
The minimum width is 960 pixels; the wide minimum height is 450 pixels. Narrow
layouts reserve additional height for the core map. Background and card opacity
remain configurable in Appearance, with more opaque glass defaults for legibility.

## Install

```bash
kpackagetool6 --type Plasma/Applet --install .
systemctl --user restart plasma-plasmashell.service
```

Then right-click the desktop, choose **Enter Edit Mode**, select **Add
Widgets**, and search for **Glass System Dashboard**.

To update an existing installation:

```bash
kpackagetool6 --type Plasma/Applet --upgrade .
systemctl --user restart plasma-plasmashell.service
```

## Transparency

Open the widget's configuration and select **Appearance**:

- Set **Widget background** to `0%` for a transparent outer background.
- Set **Card opacity** to `0%` for a completely background-free layout.
- Leave card opacity around `30–40%` for a subtle glass effect.

## License

GPL-3.0-or-later
