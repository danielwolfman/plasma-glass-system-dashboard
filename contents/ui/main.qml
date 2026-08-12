import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.ksysguard.process as Processes
import org.kde.ksysguard.sensors as Sensors

PlasmoidItem {
    id: root

    property int updateInterval: 2000
    property int historyLength: 72
    property var cpuHistory: []
    property var downloadHistory: []
    property var uploadHistory: []
    property var topCpuProcesses: []
    property var topMemoryProcesses: []
    property var topGpuProcesses: []
    property var powerTelemetry: ({ "available": false, "fans_rpm": [] })
    property bool deviceGpuCollectorBusy: false
    property bool powerTelemetryBusy: false
    property real networkMaximum: 1048576

    readonly property int warningLevel: Plasmoid.configuration.warningLevel || 70
    readonly property int criticalLevel: Plasmoid.configuration.criticalLevel || 90
    readonly property real backgroundOpacity: Math.max(0, Math.min(100, Plasmoid.configuration.backgroundOpacity)) / 100
    readonly property real cardOpacity: Math.max(0, Math.min(100, Plasmoid.configuration.cardOpacity)) / 100
    readonly property bool showAccentGlow: Plasmoid.configuration.showAccentGlow
    readonly property int logicalCpuCount: Math.max(1, Math.round(number(cpuCoreCount)))

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.title: i18n("Glass System Dashboard")
    preferredRepresentation: fullRepresentation

    function number(sensor) {
        const n = Number(sensor.value)
        return Number.isFinite(n) ? n : 0
    }

    function percentColor(value, normalColor) {
        if (value >= criticalLevel) {
            return "#ff4d62"
        }
        if (value >= warningLevel) {
            return "#ffc857"
        }
        return normalColor || "#71d7ff"
    }

    function temperatureColor(value, normalColor) {
        if (value >= 90) {
            return "#ff4d62"
        }
        if (value >= 75) {
            return "#ffc857"
        }
        return normalColor || "#71d7ff"
    }

    function appendPoint(history, value) {
        const copy = history.slice(0)
        copy.push(Number.isFinite(value) ? value : 0)
        while (copy.length > historyLength) {
            copy.shift()
        }
        return copy
    }

    function sampleHistory() {
        cpuHistory = appendPoint(cpuHistory, number(cpuUsage))
        downloadHistory = appendPoint(downloadHistory, number(networkDownload))
        uploadHistory = appendPoint(uploadHistory, number(networkUpload))

        let peak = 1048576
        for (let i = 0; i < downloadHistory.length; ++i) {
            peak = Math.max(peak, downloadHistory[i], uploadHistory[i] || 0)
        }
        networkMaximum = peak * 1.12
    }

    function gpuVramPercent(usedSensor, totalSensor) {
        const total = number(totalSensor)
        return total > 0 ? number(usedSensor) * 100 / total : 0
    }

    function shortProcessName(value) {
        let name = String(value || "unknown")
        const argumentStart = name.indexOf(" --")
        if (argumentStart > 0) {
            name = name.slice(0, argumentStart)
        }
        const pathParts = name.split("/")
        return pathParts[pathParts.length - 1]
    }

    function compactCommandLine(value) {
        const commandLine = String(value || "").trim()
        if (commandLine.length === 0) {
            return ""
        }

        const argumentStart = commandLine.search(/\s/)
        const executable = argumentStart < 0 ? commandLine : commandLine.slice(0, argumentStart)
        const argumentsText = argumentStart < 0 ? "" : commandLine.slice(argumentStart)
        const pathSeparator = executable.lastIndexOf("/")
        const processName = pathSeparator < 0 ? executable : executable.slice(pathSeparator + 1)
        return processName + argumentsText
    }

    function gpuLabel(value) {
        const gpu = String(value || "").toLowerCase()
        if (gpu.indexOf("nvidia") >= 0 || gpu.indexOf("rtx") >= 0) {
            return "RTX"
        }
        if (gpu.indexOf("intel") >= 0 || gpu.indexOf("arc") >= 0) {
            return "INTEL"
        }
        return ""
    }

    function formatKib(value) {
        const kib = Math.max(0, Number(value) || 0)
        if (kib >= 1048576) {
            return (kib / 1048576).toFixed(1) + " GiB"
        }
        if (kib >= 1024) {
            return (kib / 1024).toFixed(1) + " MiB"
        }
        return Math.round(kib) + " KiB"
    }

    function shellQuote(value) {
        return "'" + String(value).replace(/'/g, "'\"'\"'") + "'"
    }

    function collectTopProcesses(limit) {
        const cpuRows = []
        const memoryRows = []
        for (let row = 0; row < processModel.rowCount(); ++row) {
            const cpuIndex = processModel.index(row, 2)
            const memoryIndex = processModel.index(row, 3)
            const cpuValue = Number(processModel.data(cpuIndex, Processes.ProcessDataModel.Value)) || 0
            const memoryValue = Number(processModel.data(memoryIndex, Processes.ProcessDataModel.Value)) || 0
            if (cpuValue <= 0 && memoryValue <= 0) {
                continue
            }

            const processName = shortProcessName(processModel.data(processModel.index(row, 0), Processes.ProcessDataModel.Value))
            const commandLine = compactCommandLine(processModel.data(processModel.index(row, 4), Processes.ProcessDataModel.Value))
            const pid = processModel.data(processModel.index(row, 1), Processes.ProcessDataModel.Value)
            if (cpuValue > 0) {
                const displayedCpu = cpuValue / logicalCpuCount
                cpuRows.push({
                    name: commandLine.length > 0 ? commandLine : processName,
                    pid: pid,
                    value: displayedCpu,
                    rawValue: cpuValue,
                    formatted: (displayedCpu < 10 ? displayedCpu.toFixed(1) : Math.round(displayedCpu)) + "%",
                    gpuLabel: ""
                })
            }
            if (memoryValue > 0) {
                memoryRows.push({
                    name: commandLine.length > 0 ? commandLine : processName,
                    pid: pid,
                    value: memoryValue,
                    rawValue: memoryValue,
                    formatted: processModel.data(memoryIndex, Processes.ProcessDataModel.FormattedValue),
                    gpuLabel: ""
                })
            }
        }
        cpuRows.sort((left, right) => right.value - left.value)
        memoryRows.sort((left, right) => right.value - left.value)
        return {
            cpu: cpuRows.slice(0, limit),
            memory: memoryRows.slice(0, limit)
        }
    }

    function balanceGpuRows(rows, limit) {
        rows.sort((left, right) => {
            if (right.value !== left.value) {
                return right.value - left.value
            }
            return right.memory - left.memory
        })

        const perGpu = Math.max(1, Math.floor(limit / 2))
        let selected = rows.filter(entry => entry.gpuLabel === "RTX").slice(0, perGpu)
            .concat(rows.filter(entry => entry.gpuLabel === "INTEL").slice(0, perGpu))
        const selectedKeys = {}
        for (let i = 0; i < selected.length; ++i) {
            selectedKeys[selected[i].pid + ":" + selected[i].gpuLabel] = true
        }
        for (let j = 0; j < rows.length && selected.length < limit; ++j) {
            const key = rows[j].pid + ":" + rows[j].gpuLabel
            if (!selectedKeys[key]) {
                selected.push(rows[j])
                selectedKeys[key] = true
            }
        }
        selected.sort((left, right) => {
            if (right.value !== left.value) {
                return right.value - left.value
            }
            return right.memory - left.memory
        })
        return selected.slice(0, limit)
    }

    function parseDeviceGpuProcesses(output) {
        const rows = []
        const lines = String(output || "").trim().split("\n")
        for (let i = 0; i < lines.length; ++i) {
            const fields = lines[i].split("\t")
            if (fields.length < 5 || (fields[0] !== "RTX" && fields[0] !== "INTEL")) {
                continue
            }
            const usage = Number(fields[3]) || 0
            const memory = Number(fields[4]) || 0
            rows.push({
                name: shortProcessName(fields[2]),
                pid: Number(fields[1]) || 0,
                value: usage,
                memory: memory,
                formatted: (usage < 10 ? usage.toFixed(1) : Math.round(usage)) + "% · " + formatKib(memory),
                gpuLabel: fields[0]
            })
        }
        topGpuProcesses = balanceGpuRows(rows, 4)
    }

    function sampleDeviceGpuProcesses() {
        if (deviceGpuCollectorBusy) {
            return
        }
        deviceGpuCollectorBusy = true
        let path = Qt.resolvedUrl("../scripts/gpu_processes.py").toString()
        path = decodeURIComponent(path.replace(/^file:\/\//, ""))
        gpuProcessCommand.exec(shellQuote(path), function(result) {
            deviceGpuCollectorBusy = false
            if (result.exitCode === 0) {
                parseDeviceGpuProcesses(result.stdout)
            }
        })
    }

    function samplePowerTelemetry() {
        if (powerTelemetryBusy) {
            return
        }
        powerTelemetryBusy = true
        let path = Qt.resolvedUrl("../scripts/power_telemetry.py").toString()
        path = decodeURIComponent(path.replace(/^file:\/\//, ""))
        powerTelemetryCommand.exec(shellQuote(path), function(result) {
            powerTelemetryBusy = false
            if (result.exitCode !== 0) {
                return
            }
            try {
                const telemetry = JSON.parse(result.stdout)
                if (telemetry && telemetry.available !== undefined) {
                    powerTelemetry = telemetry
                }
            } catch (error) {
                console.warn("Unable to parse power telemetry:", error)
            }
        })
    }

    function powerNumber(name) {
        const value = Number(powerTelemetry[name])
        return Number.isFinite(value) ? value : 0
    }

    function batteryStateText() {
        const state = String(powerTelemetry.battery_state || "unknown")
        if (state === "pending-charge") return i18n("Charge pending")
        if (state === "fully-charged") return i18n("Fully charged")
        if (state === "not-charging") return i18n("Not charging")
        if (state === "charging") return i18n("Charging")
        if (state === "discharging") return i18n("Discharging")
        return i18n("Unknown")
    }

    function formatDuration(seconds) {
        const totalMinutes = Math.max(0, Math.round(Number(seconds) / 60))
        if (totalMinutes <= 0) return i18n("Calculating…")
        if (totalMinutes < 60) return i18n("%1 min", totalMinutes)
        const hours = Math.floor(totalMinutes / 60)
        const minutes = totalMinutes % 60
        return minutes > 0 ? i18n("%1 h %2 min", hours, minutes) : i18n("%1 h", hours)
    }

    function batteryEstimateText() {
        const state = String(powerTelemetry.battery_state || "")
        if (state === "charging") {
            return formatDuration(powerNumber("time_to_full_s")) + i18n(" to full")
        }
        if (state === "discharging") {
            return formatDuration(powerNumber("time_to_empty_s")) + i18n(" left")
        }
        if (state === "fully-charged") return i18n("On AC power")
        if (state === "pending-charge") return i18n("Charge pending")
        if (state === "not-charging") return i18n("Not charging")
        return i18n("No estimate")
    }

    function batteryFlowText() {
        const flow = powerNumber("battery_flow_w")
        if (flow > 0.05) return "+" + flow.toFixed(1) + i18n(" W in")
        if (flow < -0.05) return Math.abs(flow).toFixed(1) + i18n(" W out")
        return i18n("0 W · paused")
    }

    function batteryFlowColor() {
        const flow = powerNumber("battery_flow_w")
        if (flow > 0.05) return "#55d6be"
        if (flow < -45) return "#ff4d62"
        if (flow < -25) return "#ffc857"
        if (flow < -0.05) return "#ff9f68"
        return "#8ca3ae"
    }

    function sourceText() {
        if (!powerTelemetry.adapter_online) return i18n("Disconnected")
        const voltage = powerNumber("source_voltage_v")
        const current = powerNumber("source_current_a")
        const watts = powerNumber("source_power_w")
        const maximumWatts = powerNumber("source_max_power_w")
        if (voltage <= 0 || current <= 0) return i18n("Connected")
        if (maximumWatts > watts + 0.5) {
            return watts.toFixed(0) + i18n(" W contract · ") + maximumWatts.toFixed(0) + i18n(" W offered")
        }
        return watts.toFixed(0) + i18n(" W contract")
    }

    function fansText() {
        const fans = powerTelemetry.fans_rpm || []
        if (fans.length === 0) return i18n("Unavailable")
        return fans.map((value, index) => "F" + (index + 1) + " " + Math.round(Number(value) || 0).toLocaleString(Qt.locale())).join(" · ") + " RPM"
    }

    function fanColor() {
        const fans = powerTelemetry.fans_rpm || []
        let maximum = 0
        for (let i = 0; i < fans.length; ++i) maximum = Math.max(maximum, Number(fans[i]) || 0)
        if (maximum >= 6500) return "#ff4d62"
        if (maximum >= 5000) return "#ffc857"
        return "#71d7ff"
    }

    function batteryEnergyText() {
        const energy = powerNumber("battery_energy_wh")
        const full = powerNumber("battery_full_wh")
        const voltage = powerNumber("battery_voltage_v")
        const health = powerNumber("battery_health_percent")
        return energy.toFixed(1) + "/" + full.toFixed(1) + " Wh · " + voltage.toFixed(1) + " V · " + Math.round(health) + "%"
    }

    function updateTopProcesses() {
        const rows = collectTopProcesses(4)
        topCpuProcesses = rows.cpu
        topMemoryProcesses = rows.memory
    }

    fullRepresentation: Item {
        id: dashboard
        implicitWidth: 1180
        implicitHeight: 700 + coreMap.implicitHeight
        Layout.minimumWidth: 760
        Layout.minimumHeight: 700 + coreMap.implicitHeight
        Layout.preferredWidth: 1180
        Layout.preferredHeight: 700 + coreMap.implicitHeight

        Rectangle {
            anchors.fill: parent
            radius: 20
            visible: root.backgroundOpacity > 0
            color: Qt.rgba(0.01, 0.01, 0.012, root.backgroundOpacity)
            border.color: Qt.rgba(1, 1, 1, Math.min(0.18, root.backgroundOpacity * 0.22))
            border.width: 1
        }

        Rectangle {
            width: parent.width * 0.52
            height: parent.height * 0.9
            anchors.left: parent.left
            anchors.top: parent.top
            radius: width / 2
            color: "#0d34b7d5"
            visible: root.showAccentGlow
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    radius: 8
                    color: "#1c71d7ff"
                    border.color: "#4971d7ff"

                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: 18
                        height: 18
                        source: "utilities-system-monitor"
                        color: "#71d7ff"
                    }
                }

                Column {
                    spacing: 0
                    Text {
                        text: i18n("SYSTEM OVERVIEW")
                        color: "#edf9fc"
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.5
                    }
                    Text {
                        text: i18n("Live hardware telemetry · 1 second refresh")
                        color: "#718893"
                        font.pixelSize: 10
                    }
                }

                Item { Layout.fillWidth: true }

                Row {
                    spacing: 16
                    Text {
                        text: cpuCoreCount.formattedValue + i18n(" cores")
                        color: "#8ca3ae"
                        font.pixelSize: 11
                    }
                    Text {
                        text: Qt.formatDateTime(new Date(), "hh:mm:ss")
                        color: "#71d7ff"
                        font.pixelSize: 12
                        font.family: "monospace"

                        Timer {
                            interval: 1000
                            repeat: true
                            running: true
                            onTriggered: parent.text = Qt.formatDateTime(new Date(), "hh:mm:ss")
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 200
                Layout.preferredHeight: 1
                spacing: 12

                DashboardCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 2.25
                    title: i18n("Processor")
                    subtitle: cpuFrequency.formattedValue
                    accent: root.percentColor(root.number(cpuUsage), "#55d6be")
                    cardOpacity: root.cardOpacity

                    Item {
                        anchors.fill: parent

                        Row {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            spacing: 8
                            Text {
                                text: Math.round(root.number(cpuUsage)) + "%"
                                color: root.percentColor(root.number(cpuUsage), "#55d6be")
                                font.pixelSize: 32
                                font.weight: Font.DemiBold
                            }
                            Text {
                                anchors.baseline: parent.children[0].baseline
                                text: i18n("LOAD")
                                color: "#66808b"
                                font.pixelSize: 10
                            }
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            text: Math.round(root.number(cpuTemperature)) + "°C"
                            color: root.temperatureColor(root.number(cpuTemperature), "#9ac7d8")
                            font.pixelSize: 15
                            font.weight: Font.Medium
                        }

                        HistoryGraph {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.topMargin: 47
                            anchors.bottom: parent.bottom
                            values: root.cpuHistory
                            maximum: 100
                            lineColor: root.percentColor(root.number(cpuUsage), "#55d6be")
                            fillColor: Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.15)
                        }
                    }
                }

                DashboardCard {
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1.18
                    title: i18n("Memory")
                    subtitle: memoryUsed.formattedValue
                    accent: root.percentColor(root.number(memoryUsage), "#c792ea")
                    cardOpacity: root.cardOpacity

                    RingGauge {
                        width: Math.min(parent.width, parent.height) * 0.86
                        height: width
                        anchors.centerIn: parent
                        value: root.number(memoryUsage)
                        title: i18n("MEMORY")
                        detail: memoryTotal.formattedValue
                        color: root.percentColor(value, "#c792ea")
                    }
                }

                DashboardCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1.65
                    title: i18n("NVIDIA GPU")
                    subtitle: "RTX 500 Ada"
                    accent: root.percentColor(root.number(gpu0Usage), "#76e06f")
                    cardOpacity: root.cardOpacity

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 11

                        MeterBar {
                            Layout.fillWidth: true
                            title: i18n("CORE")
                            value: root.number(gpu0Usage)
                            valueText: Math.round(value) + "%"
                            color: root.percentColor(value, "#76e06f")
                        }
                        MeterBar {
                            Layout.fillWidth: true
                            title: i18n("VRAM")
                            value: root.gpuVramPercent(gpu0Vram, gpu0TotalVram)
                            valueText: gpu0Vram.formattedValue
                            color: root.percentColor(value, "#71d7ff")
                        }
                        MeterBar {
                            Layout.fillWidth: true
                            title: i18n("TEMP")
                            value: root.number(gpu0Temperature)
                            maximum: 100
                            valueText: Math.round(value) + "°C"
                            color: root.temperatureColor(value, "#ff9f68")
                        }
                        Item { Layout.fillHeight: true }
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: gpu0Power.formattedValue
                                color: "#8ca3ae"
                                font.pixelSize: 11
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: gpu0Frequency.formattedValue
                                color: "#8ca3ae"
                                font.pixelSize: 11
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 200
                Layout.preferredHeight: 0.92
                spacing: 12

                DashboardCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 2.25
                    title: i18n("Network")
                    subtitle: i18n("all interfaces")
                    accent: "#71d7ff"
                    cardOpacity: root.cardOpacity

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 8

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            RowLayout {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                Text { text: "↓  " + networkDownload.formattedValue; color: "#71d7ff"; font.pixelSize: 12; font.weight: Font.DemiBold }
                                Item { Layout.fillWidth: true }
                                Text { text: "↑  " + networkUpload.formattedValue; color: "#ff9f68"; font.pixelSize: 12; font.weight: Font.DemiBold }
                            }
                            HistoryGraph {
                                anchors.fill: parent
                                anchors.topMargin: 24
                                values: root.downloadHistory
                                maximum: root.networkMaximum
                                lineColor: "#71d7ff"
                                fillColor: "#1871d7ff"
                            }
                            HistoryGraph {
                                anchors.fill: parent
                                anchors.topMargin: 24
                                values: root.uploadHistory
                                maximum: root.networkMaximum
                                lineColor: "#ff9f68"
                                fillColor: "#0fff9f68"
                                gridColor: "transparent"
                            }
                        }
                    }
                }

                DashboardCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1.18
                    title: i18n("Storage")
                    subtitle: "/ · nvme0n1p2"
                    accent: root.percentColor(root.number(diskUsage), "#ffcc66")
                    cardOpacity: root.cardOpacity

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 8

                        RingGauge {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: Math.min(parent.width, parent.height) * 0.70
                            Layout.preferredHeight: Layout.preferredWidth
                            value: root.number(diskUsage)
                            title: i18n("USED")
                            detail: diskUsed.formattedValue
                            color: root.percentColor(value, "#ffcc66")
                        }
                        Item { Layout.fillHeight: true }
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "R  " + diskRead.formattedValue; color: "#7fd8be"; font.pixelSize: 10 }
                            Item { Layout.fillWidth: true }
                            Text { text: "W  " + diskWrite.formattedValue; color: "#ff9f68"; font.pixelSize: 10 }
                        }
                    }
                }

                DashboardCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1.65
                    title: i18n("INTEL GPU")
                    subtitle: "Meteor Lake Arc"
                    accent: root.percentColor(root.number(gpu1Usage), "#68a7ff")
                    cardOpacity: root.cardOpacity

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 11
                        MeterBar {
                            Layout.fillWidth: true
                            title: i18n("CORE")
                            value: root.number(gpu1Usage)
                            valueText: Math.round(value) + "%"
                            color: root.percentColor(value, "#68a7ff")
                        }
                        Item { Layout.fillHeight: true }
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: gpu1Power.formattedValue; color: "#8ca3ae"; font.pixelSize: 11 }
                            Item { Layout.fillWidth: true }
                            Text { text: gpu1Frequency.formattedValue; color: "#8ca3ae"; font.pixelSize: 11 }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 145
                Layout.preferredHeight: 0.72
                spacing: 12

                DashboardCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    title: i18n("Top CPU")
                    subtitle: i18n("whole-system share")
                    accent: "#55d6be"
                    cardOpacity: root.cardOpacity

                    TopProcessList {
                        anchors.fill: parent
                        entries: root.topCpuProcesses
                        accent: "#55d6be"
                    }
                }

                DashboardCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    title: i18n("Top Memory")
                    subtitle: i18n("resident memory")
                    accent: "#c792ea"
                    cardOpacity: root.cardOpacity

                    TopProcessList {
                        anchors.fill: parent
                        entries: root.topMemoryProcesses
                        accent: "#c792ea"
                    }
                }

                DashboardCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    title: i18n("Top GPU")
                    subtitle: i18n("RTX + Intel")
                    accent: "#76e06f"
                    cardOpacity: root.cardOpacity

                    TopProcessList {
                        anchors.fill: parent
                        entries: root.topGpuProcesses
                        accent: "#76e06f"
                        showGpuLabel: true
                    }
                }

                DashboardCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    title: i18n("Power & Cooling")
                    subtitle: powerTelemetry.adapter_online ? i18n("AC connected") : i18n("on battery")
                    accent: root.batteryFlowColor()
                    cardOpacity: root.cardOpacity

                    GridLayout {
                        anchors.fill: parent
                        columns: 2
                        columnSpacing: 12
                        rowSpacing: 4

                        TelemetryMetric {
                            Layout.fillWidth: true
                            title: i18n("BATTERY")
                            valueText: Math.round(root.powerNumber("battery_percent")) + "% · " + root.batteryStateText()
                            valueColor: root.percentColor(100 - root.powerNumber("battery_percent"), "#55d6be")
                        }
                        TelemetryMetric {
                            Layout.fillWidth: true
                            title: i18n("BATTERY FLOW")
                            valueText: root.batteryFlowText()
                            valueColor: root.batteryFlowColor()
                        }
                        TelemetryMetric {
                            Layout.fillWidth: true
                            title: i18n("ESTIMATE")
                            valueText: root.batteryEstimateText()
                            valueColor: "#c792ea"
                        }
                        TelemetryMetric {
                            Layout.fillWidth: true
                            title: i18n("USB-C PD")
                            valueText: root.sourceText()
                            valueColor: powerTelemetry.adapter_online ? "#55d6be" : "#8ca3ae"
                        }
                        TelemetryMetric {
                            Layout.fillWidth: true
                            title: i18n("COOLING FANS")
                            valueText: root.fansText()
                            valueColor: root.fanColor()
                        }
                        TelemetryMetric {
                            Layout.fillWidth: true
                            title: i18n("ENERGY / HEALTH")
                            valueText: root.batteryEnergyText()
                            valueColor: "#9ac7d8"
                        }
                    }
                }
            }

            DashboardCard {
                Layout.fillWidth: true
                Layout.preferredHeight: coreMap.implicitHeight + 42
                Layout.minimumHeight: coreMap.implicitHeight + 42
                title: i18n("CPU Core Map")
                subtitle: i18n("%1 logical processors", root.logicalCpuCount)
                accent: "#55d6be"
                cardOpacity: root.cardOpacity

                CoreMap {
                    id: coreMap
                    anchors.fill: parent
                    coreCount: root.logicalCpuCount
                    updateInterval: root.updateInterval
                    warningLevel: root.warningLevel
                    criticalLevel: root.criticalLevel
                }
            }
        }
    }

    RunCommand { id: gpuProcessCommand }
    RunCommand { id: powerTelemetryCommand }

    Processes.ProcessDataModel {
        id: processModel
        flatList: true
        enabled: true
        enabledAttributes: ["name", "pid", "usage", "memory", "command"]
    }

    Sensors.Sensor { id: cpuUsage; sensorId: "cpu/all/usage"; updateRateLimit: root.updateInterval }
    Sensors.Sensor { id: cpuTemperature; sensorId: "cpu/all/maximumTemperature"; updateRateLimit: root.updateInterval }
    Sensors.Sensor { id: cpuFrequency; sensorId: "cpu/all/averageFrequency"; updateRateLimit: root.updateInterval }
    Sensors.Sensor { id: cpuCoreCount; sensorId: "cpu/all/coreCount"; updateRateLimit: 10000 }

    Sensors.Sensor { id: memoryUsage; sensorId: "memory/physical/usedPercent"; updateRateLimit: root.updateInterval }
    Sensors.Sensor { id: memoryUsed; sensorId: "memory/physical/used"; updateRateLimit: root.updateInterval }
    Sensors.Sensor { id: memoryTotal; sensorId: "memory/physical/total"; updateRateLimit: 10000 }

    Sensors.Sensor { id: diskUsage; sensorId: "disk/all/usedPercent"; updateRateLimit: root.updateInterval }
    Sensors.Sensor { id: diskUsed; sensorId: "disk/all/used"; updateRateLimit: root.updateInterval }
    Sensors.Sensor { id: diskRead; sensorId: "disk/all/read"; updateRateLimit: root.updateInterval }
    Sensors.Sensor { id: diskWrite; sensorId: "disk/all/write"; updateRateLimit: root.updateInterval }

    Sensors.Sensor { id: networkDownload; sensorId: "network/all/download"; updateRateLimit: root.updateInterval }
    Sensors.Sensor { id: networkUpload; sensorId: "network/all/upload"; updateRateLimit: root.updateInterval }

    Sensors.Sensor { id: gpu0Usage; sensorId: "gpu/gpu0/usage"; updateRateLimit: root.updateInterval }
    Sensors.Sensor { id: gpu0Temperature; sensorId: "gpu/gpu0/temperature"; updateRateLimit: root.updateInterval }
    Sensors.Sensor { id: gpu0Vram; sensorId: "gpu/gpu0/usedVram"; updateRateLimit: root.updateInterval }
    Sensors.Sensor { id: gpu0TotalVram; sensorId: "gpu/gpu0/totalVram"; updateRateLimit: 10000 }
    Sensors.Sensor { id: gpu0Power; sensorId: "gpu/gpu0/power"; updateRateLimit: root.updateInterval }
    Sensors.Sensor { id: gpu0Frequency; sensorId: "gpu/gpu0/coreFrequency"; updateRateLimit: root.updateInterval }

    Sensors.Sensor { id: gpu1Usage; sensorId: "gpu/gpu1/usage"; updateRateLimit: root.updateInterval }
    Sensors.Sensor { id: gpu1Power; sensorId: "gpu/gpu1/power"; updateRateLimit: root.updateInterval }
    Sensors.Sensor { id: gpu1Frequency; sensorId: "gpu/gpu1/coreFrequency"; updateRateLimit: root.updateInterval }

    Timer {
        interval: root.updateInterval
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.sampleHistory()
    }

    Timer {
        interval: 3000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.updateTopProcesses()
    }

    Timer {
        interval: 5000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.sampleDeviceGpuProcesses()
    }

    Timer {
        interval: 5000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.samplePowerTelemetry()
    }
}
