import QtQuick

Rectangle {
    id: root

    property string title: ""
    property string subtitle: ""
    property color accent: "#71d7ff"
    property real cardOpacity: 0.38
    default property alias contentData: body.data

    color: Qt.rgba(0.025, 0.028, 0.032, root.cardOpacity)
    border.color: Qt.rgba(1, 1, 1, Math.min(0.16, root.cardOpacity * 0.30))
    border.width: 1
    radius: 14

    Rectangle {
        width: 3
        height: 18
        radius: 2
        color: root.accent
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.top: parent.top
        anchors.topMargin: 15
    }

    Text {
        id: heading
        text: root.title.toUpperCase()
        color: "#e8f4f8"
        font.pixelSize: 12
        font.weight: Font.DemiBold
        font.letterSpacing: 1.2
        anchors.left: parent.left
        anchors.leftMargin: 25
        anchors.top: parent.top
        anchors.topMargin: 15
    }

    Text {
        text: root.subtitle
        color: "#708893"
        font.pixelSize: 10
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: heading.verticalCenter
    }

    Item {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: heading.bottom
        anchors.bottom: parent.bottom
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        anchors.topMargin: 10
        anchors.bottomMargin: 14
    }
}
