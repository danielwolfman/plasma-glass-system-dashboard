import QtQuick
import QtQuick.Layouts

import org.kde.ksysguard.sensors as Sensors

Item {
    id: root

    required property int coreIndex
    property int updateInterval: 1000
    property bool compact: false
    property int warningLevel: 70
    property int criticalLevel: 90

    readonly property real usage: {
        const value = Number(coreUsage.value)
        return Number.isFinite(value) ? value : 0
    }
    readonly property color gaugeColor: usage >= criticalLevel
        ? "#ff4d62"
        : usage >= warningLevel ? "#ffc857" : "#55d6be"

    implicitWidth: 82
    implicitHeight: 82

    Sensors.Sensor {
        id: coreUsage
        sensorId: "cpu/cpu" + root.coreIndex + "/usage"
        updateRateLimit: root.updateInterval
    }

    RingGauge {
        visible: !root.compact
        width: Math.min(parent.width, parent.height)
        height: width
        anchors.centerIn: parent
        value: root.usage
        title: "C" + (root.coreIndex + 1)
        color: root.gaugeColor
        trackColor: "#20ffffff"
    }

    Rectangle {
        anchors.fill: parent
        visible: root.compact
        radius: 6
        color: Qt.rgba(root.gaugeColor.r, root.gaugeColor.g, root.gaugeColor.b, 0.06)

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 5
            text: "C" + (root.coreIndex + 1)
            color: "#91a8b3"
            font.pixelSize: 9
        }
        Text {
            anchors.centerIn: parent
            text: Math.round(root.usage) + "%"
            color: root.gaugeColor
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 5
            height: 3
            radius: 1.5
            color: "#20ffffff"

            Rectangle {
                width: parent.width * Math.max(0, Math.min(100, root.usage)) / 100
                height: parent.height
                radius: parent.radius
                color: root.gaugeColor
            }
        }
    }
}
