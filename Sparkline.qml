import QtQuick

// Live sparkline graph. `series` is a list of normalized 0..1 sample
// arrays (all same length, oldest first); `colors` parallels it. Each
// series renders as a rounded line with a translucent area fill beneath
// it. Repaints whenever a series array is reassigned — consumers should
// replace the array (spread + slice) rather than push into it, since
// mutation alone doesn't fire onSeriesChanged.
Item {
    id: spark

    property var series: []
    property var colors: []
    property real lineWidth: 1.8

    Canvas {
        id: cvs
        anchors.fill: parent
        antialiasing: true
        onPaint: {
            const ctx = cvs.getContext("2d");
            const w = cvs.width;
            const h = cvs.height;
            ctx.clearRect(0, 0, w, h);

            const series = spark.series;
            const colors = spark.colors;
            if (!series || series.length === 0) return;
            const n = series[0].length;
            if (n === 0) return;

            const step = w / (n - 1 || 1);

            for (let s = 0; s < series.length; s++) {
                const vals = series[s];
                const col = colors[s] || "white";
                if (!vals || vals.length === 0) continue;

                if (vals.length === 1) {
                    // Single point: a dot anchored at the bottom edge.
                    ctx.beginPath();
                    ctx.arc(0, h - Math.max(0, Math.min(1, vals[0])) * h, 1.5, 0, Math.PI * 2);
                    ctx.fillStyle = col;
                    ctx.fill();
                    continue;
                }

                // Area fill.
                ctx.beginPath();
                for (let i = 0; i < vals.length; i++) {
                    const x = i * step;
                    const y = h - Math.max(0, Math.min(1, vals[i])) * h;
                    if (i === 0) ctx.moveTo(x, y);
                    else ctx.lineTo(x, y);
                }
                ctx.lineTo(w, h);
                ctx.lineTo(0, h);
                ctx.closePath();
                ctx.fillStyle = col;
                ctx.globalAlpha = 0.16;
                ctx.fill();
                ctx.globalAlpha = 1.0;

                // Line.
                ctx.beginPath();
                for (let i = 0; i < vals.length; i++) {
                    const x = i * step;
                    const y = h - Math.max(0, Math.min(1, vals[i])) * h;
                    if (i === 0) ctx.moveTo(x, y);
                    else ctx.lineTo(x, y);
                }
                ctx.strokeStyle = col;
                ctx.lineWidth = spark.lineWidth;
                ctx.lineJoin = "round";
                ctx.lineCap = "round";
                ctx.stroke();
            }
        }
    }

    onSeriesChanged: cvs.requestPaint()
    onColorsChanged: cvs.requestPaint()
}