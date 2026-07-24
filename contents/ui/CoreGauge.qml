import QtQuick
import QtQuick.Layouts

import org.kde.ksysguard.sensors as Sensors

Item {
    id: root

    required property int coreIndex
    property int updateInterval: 1000
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
        width: Math.min(parent.width, parent.height)
        height: width
        anchors.centerIn: parent
        value: root.usage
        title: "C" + (root.coreIndex + 1)
        color: root.gaugeColor
        trackColor: "#20ffffff"
    }
}
