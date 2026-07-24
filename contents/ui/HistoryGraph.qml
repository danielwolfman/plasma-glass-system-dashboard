import QtQuick

Item {
    id: root

    property var values: []
    property color lineColor: "#71d7ff"
    property color fillColor: Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.16)
    property color gridColor: "#20ffffff"
    property real maximum: 100
    property real lineWidth: 2

    onValuesChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const w = width
            const h = height

            ctx.strokeStyle = root.gridColor
            ctx.lineWidth = 1
            for (let i = 1; i < 4; ++i) {
                const y = Math.round(h * i / 4) + 0.5
                ctx.beginPath()
                ctx.moveTo(0, y)
                ctx.lineTo(w, y)
                ctx.stroke()
            }

            if (!root.values || root.values.length < 2 || root.maximum <= 0) {
                return
            }

            const step = w / Math.max(1, root.values.length - 1)
            function pointY(value) {
                const normalized = Math.max(0, Math.min(1, Number(value) / root.maximum))
                return h - normalized * (h - 3) - 1.5
            }

            ctx.beginPath()
            ctx.moveTo(0, h)
            for (let j = 0; j < root.values.length; ++j) {
                ctx.lineTo(j * step, pointY(root.values[j]))
            }
            ctx.lineTo(w, h)
            ctx.closePath()
            ctx.fillStyle = root.fillColor
            ctx.fill()

            ctx.beginPath()
            ctx.moveTo(0, pointY(root.values[0]))
            for (let k = 1; k < root.values.length; ++k) {
                ctx.lineTo(k * step, pointY(root.values[k]))
            }
            ctx.strokeStyle = root.lineColor
            ctx.lineWidth = root.lineWidth
            ctx.lineJoin = "round"
            ctx.lineCap = "round"
            ctx.stroke()
        }
    }
}
