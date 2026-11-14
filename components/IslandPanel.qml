import QtQuick
import "../theme"

// Keep the layout at its final size while its surface grows from a dot.
Item {
    id: root
    default property alias contentData: payload.data
    property real progress: 0
    property bool exiting: false
    property color panelColor: Glass.panel
    property color panelBorder: Glass.stroke
    property real expandedRadius: Glass.radius
    property bool centered: false
    property bool verticallyCentered: false
    readonly property real dotSize: Math.min(1, width, height)
    property real originX: centered ? width / 2 : width - dotSize / 2
    readonly property real contentOpacity: Math.max(0, Math.min(1, (progress - 0.8) / 0.2))
    readonly property Item morphItem: surface
    signal opening()
    signal opened()
    signal closingStarted()
    signal hideRequested()

    function open(): void {
        motion.stop();
        exiting = false;
        opening();
        forceActiveFocus();
        motion.to = 1;
        motion.duration = 380;
        motion.easing.type = Easing.OutCubic;
        motion.start();
    }
    function close(): void {
        if (exiting) return;
        motion.stop();
        exiting = true;
        closingStarted();
        motion.to = 0;
        motion.duration = 200;
        motion.easing.type = Easing.InOutCubic;
        motion.start();
    }
    onVisibleChanged: {
        if (!visible) {
            motion.stop();
            progress = 0;
            exiting = false;
        }
    }
    property NumberAnimation motion: NumberAnimation {
        target: root
        property: "progress"
        onFinished: {
            if (root.exiting) {
                root.exiting = false;
                root.hideRequested();
            } else {
                root.opened();
            }
        }
    }
    children: [
        Rectangle {
            id: surface
            x: (root.originX - root.dotSize / 2) * (1 - root.progress)
            y: root.verticallyCentered ? (root.height - height) / 2 : 0
            width: root.dotSize + (root.width - root.dotSize) * root.progress
            height: root.dotSize + (root.height - root.dotSize) * root.progress
            radius: (1 - root.progress) * Math.min(width, height) / 2 + root.progress * root.expandedRadius
            color: root.panelColor
            border.color: root.panelBorder
            border.width: Math.min(1, width / 2, height / 2)
            clip: true

            Item {
                id: payload
                x: surface.width - width
                width: root.width
                height: root.height
                scale: Math.min(surface.width / Math.max(1, width), surface.height / Math.max(1, height))
                transformOrigin: Item.TopRight
                opacity: root.contentOpacity
                enabled: root.progress > 0.85 && !root.exiting
            }
        }
    ]
}
