import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.ksysguard.process as Processes
import org.kde.ksysguard.sensors as Sensors

PlasmoidItem {
    id: root

    property int updateInterval: 1000
    property int historyLength: 72
    property var cpuHistory: []
    property var downloadHistory: []
    property var uploadHistory: []
    property var topCpuProcesses: []
    property var topMemoryProcesses: []
    property var topGpuProcesses: []
    property bool deviceGpuCollectorBusy: false
    property bool deviceGpuCollectorReady: false
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

    function collectTopProcesses(metricColumn, limit) {
        const rows = []
        for (let row = 0; row < processModel.rowCount(); ++row) {
            const valueIndex = processModel.index(row, metricColumn)
            const value = Number(processModel.data(valueIndex, Processes.ProcessDataModel.Value)) || 0
            if (value <= 0) {
                continue
            }

            let displayedValue = value
            let formatted = processModel.data(valueIndex, Processes.ProcessDataModel.FormattedValue)
            if (metricColumn === 2) {
                displayedValue = value / logicalCpuCount
                formatted = (displayedValue < 10 ? displayedValue.toFixed(1) : Math.round(displayedValue)) + "%"
            }
            if (metricColumn === 4) {
                formatted = (value < 10 ? value.toFixed(1) : Math.round(value)) + "%"
            }

            const processName = shortProcessName(processModel.data(processModel.index(row, 0), Processes.ProcessDataModel.Value))
            const commandLine = compactCommandLine(processModel.data(processModel.index(row, 7), Processes.ProcessDataModel.Value))

            rows.push({
                name: (metricColumn === 2 || metricColumn === 3) && commandLine.length > 0 ? commandLine : processName,
                pid: processModel.data(processModel.index(row, 1), Processes.ProcessDataModel.Value),
                value: displayedValue,
                rawValue: value,
                formatted: formatted,
                gpuLabel: gpuLabel(processModel.data(processModel.index(row, 6), Processes.ProcessDataModel.Value))
            })
        }
        rows.sort((left, right) => right.value - left.value)
        return rows.slice(0, limit)
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

    function collectTopGpuProcesses(limit) {
        const rows = []
        for (let row = 0; row < processModel.rowCount(); ++row) {
            const usageIndex = processModel.index(row, 4)
            const memoryIndex = processModel.index(row, 5)
            const usage = Number(processModel.data(usageIndex, Processes.ProcessDataModel.Value)) || 0
            const memory = Number(processModel.data(memoryIndex, Processes.ProcessDataModel.Value)) || 0
            const label = gpuLabel(processModel.data(processModel.index(row, 6), Processes.ProcessDataModel.Value))

            // Retaining GPU memory still means the process is a GPU consumer,
            // even when it happens to be idle during this sample.
            if (label.length === 0 || (usage <= 0 && memory <= 0)) {
                continue
            }

            const processName = shortProcessName(processModel.data(processModel.index(row, 0), Processes.ProcessDataModel.Value))
            const usageText = (usage < 10 ? usage.toFixed(1) : Math.round(usage)) + "%"
            const memoryText = processModel.data(memoryIndex, Processes.ProcessDataModel.FormattedValue)
            rows.push({
                name: processName,
                pid: processModel.data(processModel.index(row, 1), Processes.ProcessDataModel.Value),
                value: usage,
                memory: memory,
                formatted: usageText + " · " + memoryText,
                gpuLabel: label
            })
        }

        return balanceGpuRows(rows, limit)
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
        deviceGpuCollectorReady = true
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
            } else {
                deviceGpuCollectorReady = false
            }
        })
    }

    function updateTopProcesses() {
        topCpuProcesses = collectTopProcesses(2, 4)
        topMemoryProcesses = collectTopProcesses(3, 4)
        if (!deviceGpuCollectorReady) {
            topGpuProcesses = collectTopGpuProcesses(4)
        }
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

    Processes.ProcessDataModel {
        id: processModel
        flatList: true
        enabled: true
        enabledAttributes: ["name", "pid", "usage", "memory", "gpu_usage", "gpu_memory", "gpu_module", "command"]
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
        interval: 2000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.updateTopProcesses()
    }

    Timer {
        interval: 2500
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.sampleDeviceGpuProcesses()
    }
}
