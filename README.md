# Glass System Dashboard

A wide, translucent system-monitor widget for KDE Plasma 6, inspired by the
dashboard layout of Plasma System Monitor.

It displays live CPU, memory, NVIDIA and Intel GPU, network, and storage data
through KDE's `ksystemstats` sensor backend. Values switch to yellow or red at
configurable warning and critical thresholds.

## Features

- CPU load history, frequency, and temperature
- Memory and storage ring gauges
- NVIDIA and Intel GPU utilization, memory, temperature, power, and frequency
- Network download and upload history
- Disk read and write activity
- Configurable outer-background and card opacity
- Optional accent glow
- Configurable warning and critical levels

## Requirements

- KDE Plasma 6
- `ksystemstats`
- `libksysguard`

The sensor identifiers in this version are arranged for a hybrid laptop where
`gpu0` is NVIDIA and `gpu1` is Intel. They can be adjusted in
`contents/ui/main.qml` for other hardware layouts.

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
