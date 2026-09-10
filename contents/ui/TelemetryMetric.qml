import QtQuick
import QtQuick.Layouts

GridLayout {
    id: root

    property string title: ""
    property string valueText: "—"
    property color valueColor: "#d9e8ee"

    property bool horizontal: false

    columns: horizontal ? 2 : 1
    columnSpacing: 8
    rowSpacing: 0

    Text {
        Layout.fillWidth: !root.horizontal
        Layout.preferredWidth: root.horizontal ? 86 : -1
        text: root.title
        color: "#66808b"
        font.pixelSize: 9
        font.weight: Font.Medium
        font.letterSpacing: 0.7
        elide: Text.ElideRight
    }

    Text {
        Layout.fillWidth: true
        horizontalAlignment: root.horizontal ? Text.AlignRight : Text.AlignLeft
        text: root.valueText
        color: root.valueColor
        font.pixelSize: 11
        font.weight: Font.DemiBold
        elide: Text.ElideRight
    }
}
