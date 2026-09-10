import QtQuick

Item {
    id: root

    property real value: 0
    property color color: "#71d7ff"
    property color trackColor: "#24ffffff"
    property string title: ""
    property string detail: ""

    onValueChanged: canvas.requestPaint()
    onColorChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const size = Math.min(width, height)
            const cx = width / 2
            const cy = height / 2
            const stroke = Math.max(8, size * 0.085)
            const radius = Math.max(2, size / 2 - stroke)
            const start = -Math.PI * 0.75
            const sweep = Math.PI * 1.5

            ctx.lineWidth = stroke
            ctx.lineCap = "round"
            ctx.strokeStyle = root.trackColor
            ctx.beginPath()
            ctx.arc(cx, cy, radius, start, start + sweep, false)
            ctx.stroke()

            ctx.strokeStyle = root.color
            ctx.beginPath()
            ctx.arc(cx, cy, radius, start, start + sweep * Math.max(0, Math.min(100, root.value)) / 100, false)
            ctx.stroke()
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 1

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Math.round(root.value) + "%"
            color: root.color
            font.pixelSize: Math.max(20, root.width * 0.19)
            font.weight: Font.DemiBold
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.title
            color: "#dce8ef"
            font.pixelSize: Math.max(10, root.width * 0.075)
            font.weight: Font.Medium
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.detail
            visible: text.length > 0
            color: "#90a6b2"
            font.pixelSize: Math.max(9, root.width * 0.06)
        }
    }
}
