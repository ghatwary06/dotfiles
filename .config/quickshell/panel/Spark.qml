import QtQuick

// Tiny filled sparkline for a fixed-length history ring.
//
// Deliberately a Canvas rather than a Repeater of Rectangles: at 60 samples a
// Repeater churns 60 QQuickItems every tick, where this only repaints when the
// values actually change.
Canvas {
    id: spark

    property var values: []
    property color tint: Theme.acc
    property real maxV: 100
    // Full ring length, so a partially-filled history grows in from the left
    // instead of stretching to fill and rescaling on every single tick.
    property int histLen: 60
    // NB: NOT named "baseline" — that is a FINAL property on Item and shadowing
    // it makes the whole component fail to load.
    property bool showBaseline: true

    implicitHeight: 18
    onValuesChanged: requestPaint()
    onTintChanged: requestPaint()
    onWidthChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();

        const w = width, h = height;
        if (showBaseline) {
            ctx.beginPath();
            ctx.moveTo(0, h - 0.5);
            ctx.lineTo(w, h - 0.5);
            ctx.strokeStyle = Qt.rgba(tint.r, tint.g, tint.b, 0.18);
            ctx.lineWidth = 1;
            ctx.stroke();
        }

        const n = values ? values.length : 0;
        if (n < 2)
            return;

        const span = Math.max(histLen, n) - 1;
        const step = w / span;
        const x0 = w - (n - 1) * step;

        function yFor(v) {
            const c = Math.max(0, Math.min(maxV, v));
            return h - (c / maxV) * (h - 1) - 0.5;
        }

        ctx.beginPath();
        ctx.moveTo(x0, h);
        for (let i = 0; i < n; i++)
            ctx.lineTo(x0 + i * step, yFor(values[i]));
        ctx.lineTo(x0 + (n - 1) * step, h);
        ctx.closePath();
        ctx.fillStyle = Qt.rgba(tint.r, tint.g, tint.b, 0.16);
        ctx.fill();

        ctx.beginPath();
        for (let i = 0; i < n; i++) {
            const x = x0 + i * step, y = yFor(values[i]);
            if (i === 0)
                ctx.moveTo(x, y);
            else
                ctx.lineTo(x, y);
        }
        ctx.strokeStyle = tint;
        ctx.lineWidth = 1.2;
        ctx.stroke();
    }
}
