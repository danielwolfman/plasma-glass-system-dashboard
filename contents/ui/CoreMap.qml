import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property int coreCount: 1
    property bool compact: false
    property int updateInterval: 1000
    property int warningLevel: 70
    property int criticalLevel: 90

    readonly property int columnCount: compact ? Math.min(coreCount, Math.max(1, Math.floor(width / 50)))
        : width >= 950 ? Math.min(11, coreCount)
        : width >= 650 ? Math.min(8, coreCount)
        : Math.min(6, coreCount)
    readonly property int rowCount: Math.ceil(coreCount / Math.max(1, columnCount))

    implicitHeight: rowCount * (compact ? 48 : 84) + Math.max(0, rowCount - 1) * 4

    GridLayout {
        anchors.fill: parent
        columns: root.columnCount
        rowSpacing: 4
        columnSpacing: 6

        Repeater {
            model: root.coreCount

            CoreGauge {
                required property int index

                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: root.compact ? 44 : 78
                compact: root.compact
                coreIndex: index
                updateInterval: root.updateInterval
                warningLevel: root.warningLevel
                criticalLevel: root.criticalLevel
            }
        }
    }
}
