import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    property var entries: []
    property color accent: "#71d7ff"
    property bool showGpuLabel: false

    spacing: 3

    Repeater {
        model: root.entries

        delegate: Item {
            id: processRow

            required property int index
            required property var modelData

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 22

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 2
                radius: 1
                color: "#16ffffff"

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1,
                        root.entries.length > 0 && root.entries[0].value > 0
                            ? processRow.modelData.value / root.entries[0].value
                            : 0))
                    height: parent.height
                    radius: 1
                    color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.58)

                    Behavior on width {
                        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                    }
                }
            }

            RowLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 3
                spacing: 7

                Text {
                    Layout.preferredWidth: 14
                    text: processRow.index + 1
                    color: "#536b76"
                    font.pixelSize: 10
                    font.family: "monospace"
                }

                Text {
                    Layout.fillWidth: true
                    text: processRow.modelData.name
                    color: "#d7e8ed"
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }

                Rectangle {
                    visible: root.showGpuLabel && processRow.modelData.gpuLabel.length > 0
                    Layout.preferredWidth: gpuText.implicitWidth + 10
                    Layout.preferredHeight: 16
                    radius: 5
                    color: processRow.modelData.gpuLabel === "RTX" ? "#1d76e06f" : "#1d68a7ff"
                    border.color: processRow.modelData.gpuLabel === "RTX" ? "#4776e06f" : "#4768a7ff"

                    Text {
                        id: gpuText
                        anchors.centerIn: parent
                        text: processRow.modelData.gpuLabel
                        color: processRow.modelData.gpuLabel === "RTX" ? "#76e06f" : "#68a7ff"
                        font.pixelSize: 8
                        font.weight: Font.DemiBold
                    }
                }

                Text {
                    Layout.preferredWidth: root.showGpuLabel ? 98 : 68
                    horizontalAlignment: Text.AlignRight
                    text: processRow.modelData.formatted
                    color: root.accent
                    font.pixelSize: root.showGpuLabel ? 10 : 11
                    font.weight: Font.DemiBold
                    font.family: "monospace"
                    elide: Text.ElideLeft
                }
            }
        }
    }

    Text {
        visible: root.entries.length === 0
        Layout.fillWidth: true
        Layout.fillHeight: true
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        text: qsTr("Collecting process data…")
        color: "#607984"
        font.pixelSize: 10
    }
}
