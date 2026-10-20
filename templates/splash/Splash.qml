// Matrix 95 startup splash for KSplash (Plasma 6). Rendered into
// contents/splash/Splash.qml; MatrixRain.qml and MatrixGlow.qml sit next to it.
//
// KSplash contract (plasma-workspace ksplash/ksplashqml): the root item gets an
// integer property `stage`. It is 0 until the first stage arrives. On Wayland
// the stages are 2 (initial + wm), 3 (startplasma), 4 (kcminit), 5 (ksmserver),
// and 6 (desktop) quits ksplashqml at once, so the fade-out starts at stage 5.
//
// Homage to the Windows 95 boot screen, in Matrix colors: dimmed code rain in
// place of the clouds, a waving four-pane flag, a hard-shadowed wordmark, and
// the color bar that scrolls along the bottom edge. Pure QtQuick, no shaders.

import QtQuick

Rectangle {
    id: root
    color: cBg

    property int stage: 0

    // ---- palette ({{placeholders}} are filled in by matrix-rice) ----
    readonly property color cBg: "{{BG}}"
    readonly property color cSurface: "{{SURFACE}}"
    readonly property color cInk: "{{FG}}"
    readonly property color cHead: "{{HEAD}}"
    readonly property color cDim: "{{DIM}}"
    readonly property color cFaint: "{{FAINT}}"
    readonly property color cHilite: "{{HILITE}}"

    // one layout unit: 20 px on a 1080p screen
    readonly property real u: Math.max(8, height / 54)
    readonly property string sans: "Arial"   // fontconfig maps it to Liberation Sans or the default sans

    function mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1)
    }
    // DIM -> FG -> HEAD -> FG -> DIM over t in 0..1 (first and last stop match,
    // so the bar can scroll in a seamless loop).
    function barColor(t) {
        if (t < 0.25) return mix(cDim, cInk, t / 0.25)
        if (t < 0.5) return mix(cInk, cHead, (t - 0.25) / 0.25)
        if (t < 0.75) return mix(cHead, cInk, (t - 0.5) / 0.25)
        return mix(cInk, cDim, (t - 0.75) / 0.25)
    }

    // ---- fade out at the final stage, fade in on load ----
    readonly property bool leaving: stage >= 5
    onLeavingChanged: if (leaving) { fadeIn.stop(); fadeOut.start() }
    Component.onCompleted: fadeIn.start()

    Item {
        id: scene
        anchors.fill: parent
        opacity: 0

        NumberAnimation {
            id: fadeIn
            target: scene; property: "opacity"
            from: 0; to: 1
            duration: 450
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            id: fadeOut
            target: scene; property: "opacity"
            to: 0
            duration: 350
            easing.type: Easing.InQuad
        }

        // ---- backdrop: dimmed rain where Windows 95 had clouds ----
        MatrixRain {
            anchors.fill: parent
            backgroundColor: root.cBg
            inkColor: root.cInk
            headColor: root.cHead
            dimColor: root.cDim
            glow: false
            fps: 24
            density: 0.6
            glyphSize: Math.round(root.u * 0.9)
        }
        Rectangle {
            anchors.fill: parent
            color: root.cBg
            opacity: 0.45
        }
        // darker band behind the wordmark so it reads over the rain
        Rectangle {
            width: parent.width
            height: root.u * 18
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -root.u * 1.5
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(root.cBg.r, root.cBg.g, root.cBg.b, 0) }
                GradientStop { position: 0.25; color: Qt.rgba(root.cBg.r, root.cBg.g, root.cBg.b, 0.8) }
                GradientStop { position: 0.75; color: Qt.rgba(root.cBg.r, root.cBg.g, root.cBg.b, 0.8) }
                GradientStop { position: 1.0; color: Qt.rgba(root.cBg.r, root.cBg.g, root.cBg.b, 0) }
            }
        }

        // ---- logo: waving flag + wordmark ----
        Item {
            id: logo
            width: flag.width + root.u * 2.2 + wordmark.width
            height: flag.height
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -root.u * 1.5

            // Four-pane flag cut into thin vertical strips that ride a sine wave.
            Item {
                id: flag
                readonly property int strips: 44
                readonly property real sw: width / strips
                readonly property real paneH: root.u * 4.3
                readonly property real gap: root.u * 0.4
                property real phase: 0
                width: root.u * 10.4
                height: paneH * 2 + gap + root.u * 2
                y: 0

                NumberAnimation on phase {
                    from: 0; to: Math.PI * 2
                    duration: 2600
                    loops: Animation.Infinite
                    running: true
                }

                Repeater {
                    model: flag.strips
                    delegate: Item {
                        id: col
                        required property int index
                        readonly property real fx: index / (flag.strips - 1)
                        readonly property bool isRight: fx > 0.5
                        // skip two strips in the middle for the gap between panes
                        visible: Math.abs(index - (flag.strips - 1) / 2) > 0.9
                        // wave: height of the cloth at this column
                        readonly property real arg: fx * 5.2 - flag.phase
                        readonly property real lift: Math.sin(arg) * root.u * 0.7 * (0.35 + fx * 0.65)
                        readonly property real shade: 0.8 + 0.2 * Math.cos(arg)
                        x: Math.round(index * flag.sw)
                        width: Math.ceil(flag.sw) + 1
                        y: root.u * 1 + lift
                        height: flag.height

                        Rectangle {
                            width: parent.width
                            height: flag.paneH
                            color: root.mix(root.cBg, col.isRight ? root.mix(root.cInk, root.cHead, 0.3) : root.cInk, col.shade)
                        }
                        Rectangle {
                            y: flag.paneH + flag.gap
                            width: parent.width
                            height: flag.paneH
                            color: root.mix(root.cBg, col.isRight ? root.mix(root.cInk, root.cDim, 0.45) : root.cDim, col.shade)
                        }
                    }
                }
            }

            // Wordmark with a hard, unblurred drop shadow like the original logo.
            Item {
                id: wordmark
                x: flag.width + root.u * 2.2
                anchors.verticalCenter: parent.verticalCenter
                width: ninetyFive.x + ninetyFive.width
                height: ninetyFive.height

                Text {
                    x: matrixText.x + root.u * 0.22; y: matrixText.y + root.u * 0.22
                    text: matrixText.text
                    color: root.cDim
                    font: matrixText.font
                }
                Text {
                    id: matrixText
                    x: 0
                    y: ninetyFive.y + ninetyFive.baselineOffset - baselineOffset
                    text: "Matrix"
                    color: root.cHead
                    font.family: root.sans
                    font.pixelSize: root.u * 5.8
                    font.bold: true
                }
                Text {
                    x: ninetyFive.x + root.u * 0.26; y: ninetyFive.y + root.u * 0.26
                    text: ninetyFive.text
                    color: root.cDim
                    font: ninetyFive.font
                }
                Text {
                    id: ninetyFive
                    x: matrixText.width + root.u * 0.7
                    y: 0
                    text: "95"
                    color: root.cInk
                    font.family: root.sans
                    font.pixelSize: root.u * 8.0
                    font.bold: true
                }
            }
        }

        // ---- status line ----
        Text {
            x: root.u * 2
            anchors.bottom: bar.top
            anchors.bottomMargin: root.u * 1.2
            text: "Starting Matrix 95..."
            color: root.cDim
            font.family: "JetBrains Mono"
            font.pixelSize: root.u * 0.9
        }

        // ---- the color bar along the bottom edge ----
        Item {
            id: bar
            readonly property real blockW: root.u * 0.8
            readonly property int period: 80                   // blocks per gradient cycle
            readonly property int needed: Math.ceil(width / blockW) + period + 1
            width: parent.width
            height: root.u * 1.8
            anchors.bottom: parent.bottom
            clip: true

            Rectangle { anchors.fill: parent; color: root.cBg }
            Rectangle {                                          // top edge highlight
                width: parent.width
                height: Math.max(1, Math.round(root.u * 0.1))
                color: root.cHilite
                opacity: 0.8
                z: 2
            }

            Row {
                id: strip
                height: parent.height
                spacing: 0

                NumberAnimation on x {
                    from: 0
                    to: -bar.period * bar.blockW
                    duration: 3200
                    loops: Animation.Infinite
                    running: true
                }

                Repeater {
                    model: bar.needed
                    Item {
                        required property int index
                        width: bar.blockW
                        height: bar.height
                        Rectangle {
                            x: 0
                            y: Math.max(1, Math.round(root.u * 0.1))
                            width: Math.max(1, bar.blockW - Math.max(1, Math.round(root.u * 0.1)))
                            height: parent.height - y - Math.max(1, Math.round(root.u * 0.1))
                            color: root.barColor((index % bar.period) / bar.period)
                        }
                    }
                }
            }
        }
    }
}
