import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.ksysguard.sensors as Sensors

PlasmoidItem {
    id: root

    property int updateInterval: 1000
    property int historyLength: 72
    property var cpuHistory: []
    property var downloadHistory: []
    property var uploadHistory: []
    property real networkMaximum: 1048576

    readonly property int warningLevel: Plasmoid.configuration.warningLevel || 70
    readonly property int criticalLevel: Plasmoid.configuration.criticalLevel || 90
    readonly property real backgroundOpacity: Math.max(0, Math.min(100, Plasmoid.configuration.backgroundOpacity)) / 100
    readonly property real cardOpacity: Math.max(0, Math.min(100, Plasmoid.configuration.cardOpacity)) / 100
    readonly property bool showAccentGlow: Plasmoid.configuration.showAccentGlow

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

    fullRepresentation: Item {
        id: dashboard
        implicitWidth: 1180
        implicitHeight: 620
        Layout.minimumWidth: 760
        Layout.minimumHeight: 440
        Layout.preferredWidth: 1180
        Layout.preferredHeight: 620

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
                        MeterBar {
                            Layout.fillWidth: true
                            title: i18n("MEMORY")
                            value: root.gpuVramPercent(gpu1Vram, gpu1TotalVram)
                            valueText: gpu1Vram.formattedValue
                            color: root.percentColor(value, "#c792ea")
                        }
                        MeterBar {
                            Layout.fillWidth: true
                            title: i18n("TEMP")
                            value: root.number(gpu1Temperature)
                            maximum: 100
                            valueText: value > 0 ? Math.round(value) + "°C" : "—"
                            color: value > 0 ? root.temperatureColor(value, "#ff9f68") : "#51616a"
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
        }
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
    Sensors.Sensor { id: gpu1Temperature; sensorId: "gpu/gpu1/temperature"; updateRateLimit: root.updateInterval }
    Sensors.Sensor { id: gpu1Vram; sensorId: "gpu/gpu1/usedVram"; updateRateLimit: root.updateInterval }
    Sensors.Sensor { id: gpu1TotalVram; sensorId: "gpu/gpu1/totalVram"; updateRateLimit: 10000 }
    Sensors.Sensor { id: gpu1Power; sensorId: "gpu/gpu1/power"; updateRateLimit: root.updateInterval }
    Sensors.Sensor { id: gpu1Frequency; sensorId: "gpu/gpu1/coreFrequency"; updateRateLimit: root.updateInterval }

    Timer {
        interval: root.updateInterval
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.sampleHistory()
    }
}
