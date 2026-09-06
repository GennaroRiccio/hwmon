import QtQuick

// Doughnut pie showing 0..100 %. Center text is optional via showLabel.
Item {
    id: pie

    property real value: 0          // 0..100
    property color color: "#c4746e"
    property color trackColor: Qt.rgba(0.77, 0.79, 0.77, 0.12)
    property real thickness: 5
    property bool showLabel: true
    property string label: Math.round(value) + "%"
    property color labelColor: "#c5c9c5"
    property string fontFamily: "JetBrainsMono Nerd Font"

    width: 56
    height: 56

    Canvas {
        id: cvs
        anchors.fill: parent
        antialiasing: true
        onPaint: {
            const ctx = getContext("2d");
            const w = width, h = height;
            const cx = w / 2, cy = h / 2;
            const r = Math.min(w, h) / 2 - pie.thickness / 2 - 1;
            const start = -Math.PI / 2;
            const v = Math.max(0, Math.min(100, pie.value));
            const end = start + (v / 100) * Math.PI * 2;

            ctx.clearRect(0, 0, w, h);

            // track
            ctx.beginPath();
            ctx.arc(cx, cy, r, 0, Math.PI * 2);
            ctx.strokeStyle = pie.trackColor;
            ctx.lineWidth = pie.thickness;
            ctx.lineCap = "round";
            ctx.stroke();

            if (v > 0.1) {
                ctx.beginPath();
                ctx.arc(cx, cy, r, start, end, false);
                ctx.strokeStyle = pie.color;
                ctx.lineWidth = pie.thickness;
                ctx.lineCap = "round";
                ctx.stroke();
            }
        }
    }

    Text {
        visible: pie.showLabel
        anchors.centerIn: parent
        text: pie.label
        color: pie.labelColor
        font.family: pie.fontFamily
        font.pixelSize: 11
        font.weight: Font.Medium
        font.letterSpacing: 0.5
    }

    onValueChanged: cvs.requestPaint()
    onColorChanged: cvs.requestPaint()
    onTrackColorChanged: cvs.requestPaint()
    Component.onCompleted: cvs.requestPaint()
}
