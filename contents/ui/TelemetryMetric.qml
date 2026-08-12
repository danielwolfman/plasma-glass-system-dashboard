import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    property string title: ""
    property string valueText: "—"
    property color valueColor: "#d9e8ee"

    spacing: 0

    Text {
        Layout.fillWidth: true
        text: root.title
        color: "#66808b"
        font.pixelSize: 9
        font.weight: Font.Medium
        font.letterSpacing: 0.7
        elide: Text.ElideRight
    }

    Text {
        Layout.fillWidth: true
        text: root.valueText
        color: root.valueColor
        font.pixelSize: 11
        font.weight: Font.DemiBold
        elide: Text.ElideRight
    }
}
