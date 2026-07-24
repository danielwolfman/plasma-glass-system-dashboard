import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    property string title: ""
    property string valueText: ""
    property real value: 0
    property real maximum: 100
    property color color: "#71d7ff"

    spacing: 4

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            text: root.title
            color: "#a9bdc7"
            font.pixelSize: 11
            font.weight: Font.Medium
        }
        Item { Layout.fillWidth: true }
        Text {
            text: root.valueText
            color: root.color
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 7
        radius: height / 2
        color: "#24ffffff"

        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, root.maximum > 0 ? root.value / root.maximum : 0))
            height: parent.height
            radius: height / 2
            color: root.color

            Behavior on width {
                NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
            }
        }
    }
}
