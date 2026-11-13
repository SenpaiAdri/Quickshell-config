import QtQuick

// Resolution independent Wi-Fi arcs; no font-specific private-use characters.
Canvas {
    id: root
    property color ink: "white"
    property int strength: 100
    onInkChanged: requestPaint()
    onStrengthChanged: requestPaint()
    onPaint: {
        const c = getContext("2d");
        c.clearRect(0, 0, width, height);
        c.save();
        c.translate(width / 2, height * 0.85);
        c.lineCap = "round";
        c.lineWidth = Math.max(1.5, width / 10);
        for (let i = 0; i < 3; i++) {
            c.globalAlpha = strength >= [10, 40, 70][i] ? 1 : 0.24;
            c.strokeStyle = ink;
            c.beginPath();
            c.arc(0, 0, width * [0.23, 0.43, 0.64][i], -Math.PI * 0.76, -Math.PI * 0.24);
            c.stroke();
        }
        c.globalAlpha = 1;
        c.fillStyle = ink;
        c.beginPath();
        c.arc(0, 0, width * 0.065, 0, 2 * Math.PI);
        c.fill();
        c.restore();
    }
}
