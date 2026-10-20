// Matrix 95 SDDM login theme (Qt 6): a Windows 95 "Welcome" log-on dialog
// floating over the live Matrix code rain.
// Uses only plain QtQuick plus SDDM's context objects: sddm, userModel,
// sessionModel and config (values from theme.conf). MatrixRain.qml and
// MatrixGlow.qml are copied next to this file at install time.
//
// All sizes below are written in "design pixels" (a Windows 95 screen was
// 640x480) and multiplied by `px`, an integer scale, so the bevels stay
// crisp one-pixel-grid lines on any resolution.

import QtQuick

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: bg

    // ---- palette (theme.conf), with fallbacks for an older theme.conf ----
    function pick(v, fallback) { return (v !== undefined && v !== null && String(v) !== "") ? v : fallback }
    readonly property color bg: config.background
    readonly property color surface: config.surface
    readonly property color ink: config.ink
    readonly property color head: config.head
    readonly property color dim: config.dim
    readonly property color faint: config.faint
    readonly property color alert: config.alert
    readonly property color face: pick(config.face, surface)
    readonly property color hilite: pick(config.hilite, ink)
    readonly property color light: pick(config.light, faint)
    readonly property color shadow: pick(config.shadow, bg)
    readonly property color dkshadow: pick(config.dkshadow, "#000000")
    readonly property color titleFill: pick(config.title, dim)
    readonly property color titleOff: pick(config.titleinactive, faint)
    readonly property color titleOffText: pick(config.titleinactivetext, dim)
    readonly property string mono: config.font || "monospace"

    readonly property int px: Math.max(1, Math.round(Math.min(width, height) / 540))
    readonly property int fontPx: 11 * px

    // ---- state ----
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property bool busy: false
    property bool shutOpen: false
    property bool introDone: false
    property string statusText: "Ready."
    property bool statusError: false

    function tryLogin() {
        if (busy)
            return
        if (userField.text.length === 0) {
            userField.focusInput()
            return
        }
        busy = true
        statusError = false
        statusText = "Logging on..."
        sddm.login(userField.text, passwordField.text, root.sessionIndex)
    }

    function openShutdown() {
        if (!(sddm.canPowerOff || sddm.canReboot || sddm.canSuspend))
            return
        shutDialog.choice = sddm.canPowerOff ? 0 : (sddm.canReboot ? 1 : 2)
        shutOpen = true
        yesButton.forceActiveFocus()
    }

    function closeShutdown() {
        shutOpen = false
        passwordField.focusInput()
    }

    function doShutdown() {
        var c = shutDialog.choice
        shutOpen = false
        if (c === 0) sddm.powerOff()
        else if (c === 1) sddm.reboot()
        else sddm.suspend()
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.busy = false
            passwordField.text = ""
            passwordField.focusInput()
            root.statusError = true
            root.statusText = "Incorrect user name or password."
            shake.restart()
        }
        function onLoginSucceeded() {
            root.statusError = false
            root.statusText = "Welcome to Matrix 95!"
        }
    }

    // =====================================================================
    // Reusable Windows 95 pieces. Inline components do not see ids of this
    // file, so the palette travels in through `pal` and the scale in `px`.
    // =====================================================================

    // 3D frame. kind: "raised" | "sunken" | "pressed" | "thin-raised" | "thin-sunken"
    component Bevel: Item {
        id: bv
        property var pal
        property int px: 1
        property string kind: "raised"
        property color fill: pal.face
        default property alias content: inner.data
        readonly property int ring: kind.indexOf("thin") === 0 ? 1 : 2
        readonly property var c: {
            switch (kind) {
            case "sunken":      return [pal.shadow, pal.hilite, pal.dkshadow, pal.light]
            case "pressed":     return [pal.dkshadow, pal.dkshadow, pal.shadow, fill]
            case "thin-raised": return [pal.hilite, pal.shadow, fill, fill]
            case "thin-sunken": return [pal.shadow, pal.hilite, fill, fill]
            default:            return [pal.hilite, pal.dkshadow, pal.light, pal.shadow]
            }
        }
        // outer bottom-right, outer top-left, inner bottom-right, inner top-left
        Rectangle { anchors.fill: parent; color: bv.c[1] }
        Rectangle { width: parent.width - bv.px; height: parent.height - bv.px; color: bv.c[0] }
        Rectangle {
            visible: bv.ring === 2
            x: bv.px; y: bv.px
            width: parent.width - 2 * bv.px; height: parent.height - 2 * bv.px
            color: bv.c[3]
        }
        Rectangle {
            visible: bv.ring === 2
            x: bv.px; y: bv.px
            width: parent.width - 3 * bv.px; height: parent.height - 3 * bv.px
            color: bv.c[2]
        }
        Rectangle {
            x: bv.ring * bv.px; y: bv.ring * bv.px
            width: parent.width - 2 * bv.ring * bv.px; height: parent.height - 2 * bv.ring * bv.px
            color: bv.fill
        }
        Item {
            id: inner
            x: bv.ring * bv.px; y: bv.ring * bv.px
            width: parent.width - 2 * bv.ring * bv.px; height: parent.height - 2 * bv.ring * bv.px
        }
    }

    // Pixel-art bitmap from strings. Each row is merged into horizontal runs
    // so a 16x16 icon costs a few dozen rectangles, not 256.
    component PixelArt: Item {
        id: pa
        property var rows: []
        property var colors: ({})
        property int cell: 2
        width: (rows.length > 0 ? rows[0].length : 0) * cell
        height: rows.length * cell
        readonly property var runs: {
            var out = []
            for (var y = 0; y < rows.length; y++) {
                var r = rows[y], x = 0
                while (x < r.length) {
                    var ch = r.charAt(x), s = x
                    while (x < r.length && r.charAt(x) === ch) x++
                    if (ch !== "." && colors[ch] !== undefined)
                        out.push({ x: s, y: y, w: x - s, color: colors[ch] })
                }
            }
            return out
        }
        Repeater {
            model: pa.runs
            Rectangle {
                required property var modelData
                x: modelData.x * pa.cell; y: modelData.y * pa.cell
                width: modelData.w * pa.cell; height: pa.cell
                color: modelData.color
            }
        }
    }

    // 1-pixel dotted focus rectangle.
    component Dotted: Item {
        id: dt
        property color dot: "white"
        property int px: 1
        Repeater { model: Math.max(0, Math.ceil(dt.width / (2 * dt.px)))
            Rectangle { x: index * 2 * dt.px; y: 0; width: dt.px; height: dt.px; color: dt.dot } }
        Repeater { model: Math.max(0, Math.ceil(dt.width / (2 * dt.px)))
            Rectangle { x: index * 2 * dt.px; y: dt.height - dt.px; width: dt.px; height: dt.px; color: dt.dot } }
        Repeater { model: Math.max(0, Math.ceil(dt.height / (2 * dt.px)))
            Rectangle { x: 0; y: index * 2 * dt.px; width: dt.px; height: dt.px; color: dt.dot } }
        Repeater { model: Math.max(0, Math.ceil(dt.height / (2 * dt.px)))
            Rectangle { x: dt.width - dt.px; y: index * 2 * dt.px; width: dt.px; height: dt.px; color: dt.dot } }
    }

    // Push button. `isDefault` adds the classic extra dark outer border.
    component PushButton: Item {
        id: pb
        property var pal
        property int px: 1
        property string text: ""
        property bool isDefault: false
        property bool down: false
        signal clicked()
        activeFocusOnTab: true
        Keys.onPressed: (e) => {
            if (e.key === Qt.Key_Space) { pb.down = true; e.accepted = true }
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { pb.clicked(); e.accepted = true }
        }
        Keys.onReleased: (e) => {
            if (e.key === Qt.Key_Space && pb.down) { pb.down = false; pb.clicked(); e.accepted = true }
        }

        // Extra dark ring around the default button.
        Rectangle {
            anchors.fill: parent
            visible: pb.isDefault || pb.activeFocus
            color: pb.pal.dkshadow
        }
        Bevel {
            pal: pb.pal; px: pb.px
            x: (pb.isDefault || pb.activeFocus) ? pb.px : 0
            y: x
            width: parent.width - 2 * x; height: parent.height - 2 * x
            kind: (pb.down || mouse.pressed && mouse.containsMouse) ? "pressed" : "raised"
            readonly property bool sunk: kind === "pressed"
            Text {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: parent.sunk ? pb.px : 0
                anchors.verticalCenterOffset: parent.sunk ? pb.px : 0
                text: pb.text
                textFormat: Text.StyledText
                color: pb.pal.ink
                font.family: pb.pal.mono
                font.pixelSize: pb.pal.fontPx
                font.bold: pb.isDefault
            }
            Dotted {
                visible: pb.activeFocus
                x: 3 * pb.px + (parent.sunk ? pb.px : 0); y: x
                width: parent.width - 6 * pb.px - 0; height: parent.height - 6 * pb.px
                dot: pb.pal.ink; px: pb.px
            }
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            onPressed: pb.forceActiveFocus()
            onClicked: pb.clicked()
        }
    }

    // Sunken single-line edit with an I-beam caret.
    component Field: Bevel {
        id: fd
        property alias text: input.text
        property alias echoMode: input.echoMode
        property alias input: input
        property bool locked: false
        signal accepted()
        kind: "sunken"
        fill: pal.bg
        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 2 * fd.px
            anchors.rightMargin: 2 * fd.px
            verticalAlignment: TextInput.AlignVCenter
            color: fd.pal.ink
            selectionColor: fd.pal.titleFill
            selectedTextColor: fd.pal.head
            font.family: fd.pal.mono
            font.pixelSize: fd.pal.fontPx
            passwordCharacter: "*"
            clip: true
            enabled: !fd.locked
            selectByMouse: true
            onAccepted: fd.accepted()
            // Classic I-beam: a 1px stem with small serifs top and bottom.
            cursorDelegate: Item {
                width: fd.px
                Rectangle { anchors.fill: parent; color: fd.pal.head }
                Rectangle { x: -fd.px; y: 0; width: 3 * fd.px; height: fd.px; color: fd.pal.head }
                Rectangle { x: -fd.px; y: parent.height - fd.px; width: 3 * fd.px; height: fd.px; color: fd.pal.head }
            }
        }
    }

    // Title bar: solid fill, bold text, optional close button.
    component TitleBar: Rectangle {
        id: tb
        property var pal
        property int px: 1
        property string text: ""
        property bool active: true
        property bool closable: true
        signal closeClicked()
        height: 18 * px
        color: active ? pal.titleFill : pal.titleOff
        Text {
            x: 3 * tb.px
            anchors.verticalCenter: parent.verticalCenter
            text: tb.text
            color: tb.active ? tb.pal.head : tb.pal.titleOffText
            font.family: tb.pal.mono
            font.pixelSize: tb.pal.fontPx
            font.bold: true
        }
        Item {
            visible: tb.closable
            width: 16 * tb.px; height: 14 * tb.px
            x: parent.width - width - 2 * tb.px
            y: 2 * tb.px
            Bevel {
                id: closeBevel
                anchors.fill: parent
                pal: tb.pal; px: tb.px
                kind: closeMouse.pressed && closeMouse.containsMouse ? "pressed" : "raised"
                PixelArt {
                    readonly property int o: closeBevel.kind === "pressed" ? tb.px : 0
                    x: (parent.width - width) / 2 + o - tb.px * 0
                    y: (parent.height - height) / 2 + o
                    cell: tb.px
                    rows: ["##...##", ".##.##.", "..###..", "..###..", ".##.##.", "##...##"]
                    colors: ({ "#": tb.pal.head })
                }
            }
            MouseArea { id: closeMouse; anchors.fill: parent; onClicked: tb.closeClicked() }
        }
    }

    // ---- icons ----
    // 32x32 pixel art (H highlight, F body, D shade, O outline, S screen, T text).
    readonly property var keyArt: [
        "................................",
        "........OOOO....................",
        ".....OOOOHHOOOO.................",
        "....OOHHHFFHHHOO................",
        "...OOHFFFFFFFFHOO...............",
        "..OOHFFFFFFFFFFHOO..............",
        "..OHFFFFFFFFFFFFHO..............",
        "..OHFFFF....FFFFDO..............",
        ".OOHFFF......FFFDOO.............",
        ".OHFFFF......FFFFHO.............",
        ".OHFFFF......FFFFDO.............",
        ".OOHFFF......FFFDOO.............",
        "..OHFFFF....FFFFDO..............",
        "..OHFFFFFFFFFFFFDOO.............",
        "..OOHFFFFFFFFFFFFHOO............",
        "...OOHFFFFFFFFFFFFHOO...........",
        "....OOHDDFFDDDFFFFFHOO..........",
        ".....OOOOHDOOOHFFFFFHOO.........",
        "........OOOO.OOHFFFFFHOO........",
        "..............OOHFFFFFHOO.......",
        "...............OOHFFFFFHOO......",
        "................OOHFFFFFHOO.....",
        ".................OOHFFFFFHOO....",
        "..................OHFFFFFFHOO...",
        "..................OHFFFFFFFHOO..",
        "..................OHFFFFFFFFHOO.",
        "..................OHFFFDFFFFFHO.",
        "..................OHDDDOHFFFFDO.",
        "..................OOOOOOHFFFFDO.",
        ".......................OHFFFDDO.",
        ".......................OHDDDOOO.",
        ".......................OOOOOO..."
    ]
    readonly property var monitorArt: [
        "................................",
        "................................",
        "................................",
        "..OOOOOOOOOOOOOOOOOOOOOOOOOOOO..",
        "..OHHHHHHHHHHHHHHHHHHHHHHHHHHO..",
        "..OHFFFFFFFFFFFFFFFFFFFFFFFFDO..",
        "..OHFFFFFFFFFFFFFFFFFFFFFFFFDO..",
        "..OHFFSSSSSSSSSSSSSSSSSSSSFFDO..",
        "..OHFFSSSSSSSSSSSSSSSSSSSSFFDO..",
        "..OHFFSSSSSSSSSSSSSSSSSSSSFFDO..",
        "..OHFFSSTTTTTTTTTTTTTTSSSSFFDO..",
        "..OHFFSSSSSSSSSSSSSSSSSSSSFFDO..",
        "..OHFFSSSSSSSSSSSSSSSSSSSSFFDO..",
        "..OHFFSSTTTTTTTTTSSSSSSSSSFFDO..",
        "..OHFFSSSSSSSSSSSSSSSSSSSSFFDO..",
        "..OHFFSSSSSSSSSSSSSSSSSSSSFFDO..",
        "..OHFFSSTTTTTTTTTTTTTTSSSSFFDO..",
        "..OHFFSSSSSSSSSSSSSSSSSSSSFFDO..",
        "..OHFFSSSSSSSSSSSSSSSSSSSSFFDO..",
        "..OHFFSSSSSSSSSSSSSSSSSSSSFFDO..",
        "..OHFFSSSSSSSSSSSSSSSSSSSSFFDO..",
        "..OHFFFFFFFFFFFFFFFFFFFFFFFFDO..",
        "..OHFFFFFFFFFFFFFFFFFFFFFFFFDO..",
        "..OHDDDDDDDFFFFFFFFFFDDDDDDDDO..",
        "..OOOOOOOOOHFFFFFFFFDOOOOOOOOO..",
        "..........OHFFFFFFFFDO..........",
        "......OOOOOHFFFFFFFFDOOOOO......",
        "......OHHHHFFFFFFFFFFHHHHO......",
        "......OHFFFFFFFFFFFFFFFFDO......",
        "......OHDDDDDDDDDDDDDDDDDO......",
        "......OOOOOOOOOOOOOOOOOOOO......",
        "................................"
    ]
    // 16x16 version for the taskbar button.
    readonly property var keyArtSmall: [
        "................",
        "...HHHH.........",
        "..HFFFFD........",
        ".HFD..DFD.......",
        ".HF....FD.......",
        ".HF....FD.......",
        ".HFD..DFD.......",
        "..HFFFFFD.......",
        "...DDDFFD.......",
        ".......FFD......",
        "........FFD.....",
        "........FFFFD...",
        ".........FDFD...",
        ".........FDFFD..",
        "..........DDDD..",
        "................"
    ]
    readonly property var iconColors: ({ "H": head, "F": ink, "D": dim, "O": faint })
    readonly property var monitorColors: ({ "H": ink, "F": dim, "D": faint, "O": dkshadow, "S": bg, "T": head })

    // =====================================================================
    // Scene
    // =====================================================================

    MatrixRain {
        anchors.fill: parent
        backgroundColor: root.bg
        inkColor: root.ink
        headColor: root.head
        dimColor: root.dim
        glow: String(config.glow) !== "false"
        glyphSize: Math.round(root.px * 9)
        density: 0.6
    }

    // ---- the log-on dialog ----
    Item {
        id: dialog
        width: 394 * root.px
        height: (sessionRow.visible ? 202 : 172) * root.px
        x: Math.round((root.width - width) / 2) + shakeX
        y: Math.round((root.height - 28 * root.px - height) / 2)
        opacity: root.introDone ? 1 : 0
        property real shakeX: 0

        SequentialAnimation {
            id: shake
            NumberAnimation { target: dialog; property: "shakeX"; to: -10 * root.px; duration: 40 }
            NumberAnimation { target: dialog; property: "shakeX"; to: 10 * root.px; duration: 60 }
            NumberAnimation { target: dialog; property: "shakeX"; to: -7 * root.px; duration: 60 }
            NumberAnimation { target: dialog; property: "shakeX"; to: 5 * root.px; duration: 50 }
            NumberAnimation { target: dialog; property: "shakeX"; to: 0; duration: 40 }
        }

        // hard drop shadow, like the real thing
        Rectangle {
            x: 3 * root.px; y: 3 * root.px
            width: parent.width; height: parent.height
            color: Qt.rgba(0, 0, 0, 0.55)
        }

        Bevel {
            id: frame
            anchors.fill: parent
            pal: root; px: root.px
            kind: "raised"
            enabled: !root.shutOpen

            TitleBar {
                x: 2 * root.px; y: 2 * root.px
                width: parent.width - 4 * root.px
                pal: root; px: root.px
                text: "Welcome to Matrix 95"
                active: !root.shutOpen
                onCloseClicked: {
                    passwordField.text = ""
                    userField.focusInput()
                }
            }

            Item {
                id: client
                x: 2 * root.px; y: 2 * root.px + 18 * root.px
                width: parent.width - 4 * root.px

                PixelArt {
                    x: 12 * root.px; y: 14 * root.px
                    cell: root.px
                    rows: root.keyArt
                    colors: root.iconColors
                }

                Text {
                    x: 56 * root.px; y: 14 * root.px
                    width: 228 * root.px
                    text: "Type a user name and password to log on."
                    wrapMode: Text.WordWrap
                    color: root.ink
                    font.family: root.mono
                    font.pixelSize: root.fontPx
                    lineHeight: 1.1
                }

                // ---- fields ----
                Text {
                    x: 56 * root.px; y: 58 * root.px
                    height: 22 * root.px
                    verticalAlignment: Text.AlignVCenter
                    textFormat: Text.StyledText
                    text: "<u>U</u>ser name:"
                    color: root.ink
                    font.family: root.mono
                    font.pixelSize: root.fontPx
                }
                Field {
                    id: userField
                    x: 138 * root.px; y: 58 * root.px
                    width: 150 * root.px; height: 22 * root.px
                    pal: root; px: root.px
                    locked: root.busy
                    text: userModel.lastUser
                    input.KeyNavigation.tab: passwordField.input
                    onAccepted: passwordField.input.forceActiveFocus()
                    function focusInput() { input.forceActiveFocus() }
                }

                Text {
                    x: 56 * root.px; y: 88 * root.px
                    height: 22 * root.px
                    verticalAlignment: Text.AlignVCenter
                    textFormat: Text.StyledText
                    text: "<u>P</u>assword:"
                    color: root.ink
                    font.family: root.mono
                    font.pixelSize: root.fontPx
                }
                Field {
                    id: passwordField
                    x: 138 * root.px; y: 88 * root.px
                    width: 150 * root.px; height: 22 * root.px
                    pal: root; px: root.px
                    locked: root.busy
                    echoMode: TextInput.Password
                    input.KeyNavigation.tab: sessionRow.visible ? combo : okButton
                    input.KeyNavigation.backtab: userField.input
                    input.Keys.onEscapePressed: input.text = ""
                    onAccepted: root.tryLogin()
                    function focusInput() { input.forceActiveFocus() }
                }

                // ---- session picker (only with more than one session) ----
                Item {
                    id: sessionRow
                    visible: sessionRep.count > 1
                    x: 0; y: 118 * root.px
                    width: parent.width; height: 22 * root.px

                    Text {
                        x: 56 * root.px
                        height: parent.height
                        verticalAlignment: Text.AlignVCenter
                        textFormat: Text.StyledText
                        text: "<u>S</u>ession:"
                        color: root.ink
                        font.family: root.mono
                        font.pixelSize: root.fontPx
                    }

                    Bevel {
                        id: combo
                        x: 138 * root.px
                        width: 150 * root.px; height: parent.height
                        pal: root; px: root.px
                        kind: "sunken"
                        fill: root.bg
                        activeFocusOnTab: true
                        property bool open: false
                        Keys.onPressed: (e) => {
                            if (e.key === Qt.Key_Down || e.key === Qt.Key_Right) {
                                root.sessionIndex = (root.sessionIndex + 1) % sessionRep.count; e.accepted = true
                            } else if (e.key === Qt.Key_Up || e.key === Qt.Key_Left) {
                                root.sessionIndex = (root.sessionIndex + sessionRep.count - 1) % sessionRep.count; e.accepted = true
                            } else if (e.key === Qt.Key_Space || e.key === Qt.Key_F4) {
                                combo.open = !combo.open; e.accepted = true
                            } else if (e.key === Qt.Key_Escape && combo.open) {
                                combo.open = false; e.accepted = true
                            }
                        }
                        KeyNavigation.tab: okButton
                        KeyNavigation.backtab: passwordField.input
                        onActiveFocusChanged: if (!activeFocus) open = false

                        // Selected row looks like a focused list item.
                        Rectangle {
                            x: 0; y: 0
                            width: parent.width - 18 * root.px; height: parent.height
                            color: combo.activeFocus ? root.titleFill : "transparent"
                            Repeater {
                                id: sessionRep
                                model: sessionModel
                                Text {
                                    required property string name
                                    required property int index
                                    visible: index === root.sessionIndex
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: 2 * root.px
                                    width: parent.width - 4 * root.px
                                    text: name
                                    elide: Text.ElideRight
                                    color: combo.activeFocus ? root.head : root.ink
                                    font.family: root.mono
                                    font.pixelSize: root.fontPx
                                }
                            }
                        }
                        Bevel {
                            x: parent.width - 16 * root.px
                            y: 0
                            width: 16 * root.px; height: parent.height
                            pal: root; px: root.px
                            kind: arrowMouse.pressed ? "pressed" : "raised"
                            PixelArt {
                                x: (parent.width - width) / 2 + (parent.kind === "pressed" ? root.px : 0)
                                y: (parent.height - height) / 2 + (parent.kind === "pressed" ? root.px : 0)
                                cell: root.px
                                rows: ["#######", ".#####.", "..###..", "...#..."]
                                colors: ({ "#": root.ink })
                            }
                            MouseArea {
                                id: arrowMouse
                                anchors.fill: parent
                                onClicked: { combo.forceActiveFocus(); combo.open = !combo.open }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            anchors.rightMargin: 18 * root.px
                            onClicked: { combo.forceActiveFocus(); combo.open = !combo.open }
                        }

                        // drop-down list
                        Rectangle {
                            visible: combo.open
                            z: 20
                            x: -root.px; y: parent.height
                            width: parent.width + 2 * root.px
                            height: sessionRep.count * 16 * root.px + 2 * root.px
                            color: root.bg
                            border.color: root.hilite
                            border.width: root.px
                            Column {
                                x: root.px; y: root.px
                                width: parent.width - 2 * root.px
                                Repeater {
                                    model: sessionModel
                                    Rectangle {
                                        required property string name
                                        required property int index
                                        width: parent.width; height: 16 * root.px
                                        color: index === root.sessionIndex ? root.titleFill : "transparent"
                                        Text {
                                            x: 2 * root.px
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - 4 * root.px
                                            text: name
                                            elide: Text.ElideRight
                                            color: index === root.sessionIndex ? root.head : root.ink
                                            font.family: root.mono
                                            font.pixelSize: root.fontPx
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: { root.sessionIndex = index; combo.open = false }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ---- buttons (right column) ----
                PushButton {
                    id: okButton
                    x: 298 * root.px; y: 14 * root.px
                    width: 78 * root.px; height: 25 * root.px
                    pal: root; px: root.px
                    text: "OK"
                    isDefault: true
                    onClicked: root.tryLogin()
                    KeyNavigation.tab: shutButton
                    KeyNavigation.backtab: sessionRow.visible ? combo : passwordField.input
                }
                PushButton {
                    id: shutButton
                    x: 298 * root.px; y: 45 * root.px
                    width: 78 * root.px; height: 25 * root.px
                    pal: root; px: root.px
                    text: "Shut Down"
                    visible: sddm.canPowerOff || sddm.canReboot || sddm.canSuspend
                    onClicked: root.openShutdown()
                    KeyNavigation.tab: userField.input
                    KeyNavigation.backtab: okButton
                }

                // ---- status line ----
                Bevel {
                    id: statusBar
                    x: 12 * root.px
                    y: (sessionRow.visible ? 150 : 120) * root.px
                    width: parent.width - 24 * root.px; height: 20 * root.px
                    pal: root; px: root.px
                    kind: "thin-sunken"
                    fill: root.face
                    Text {
                        x: 4 * root.px
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 8 * root.px
                        text: root.statusText
                        elide: Text.ElideRight
                        color: root.statusError ? root.alert : root.ink
                        font.family: root.mono
                        font.pixelSize: root.fontPx
                        font.bold: root.statusError
                    }
                }
            }
        }
    }

    // ---- window-open "outline zoom": a stepped rectangle, no easing ----
    Rectangle {
        id: zoomOutline
        visible: !root.introDone && zoomStep > 0
        property real zoomStep: 0
        width: dialog.width * zoomStep; height: dialog.height * zoomStep
        x: dialog.x + (dialog.width - width) / 2
        y: dialog.y + (dialog.height - height) / 2
        color: "transparent"
        border.color: root.head
        border.width: root.px
    }
    SequentialAnimation {
        id: intro
        PauseAnimation { duration: 150 }
        ScriptAction { script: zoomOutline.zoomStep = 0.12 }
        PauseAnimation { duration: 35 }
        ScriptAction { script: zoomOutline.zoomStep = 0.28 }
        PauseAnimation { duration: 35 }
        ScriptAction { script: zoomOutline.zoomStep = 0.5 }
        PauseAnimation { duration: 35 }
        ScriptAction { script: zoomOutline.zoomStep = 0.76 }
        PauseAnimation { duration: 35 }
        ScriptAction { script: zoomOutline.zoomStep = 1.0 }
        PauseAnimation { duration: 35 }
        ScriptAction {
            script: {
                root.introDone = true
                if (userField.text.length > 0) passwordField.focusInput()
                else userField.focusInput()
            }
        }
    }

    // ---- taskbar with the "active window" button and the tray clock ----
    Bevel {
        id: taskbar
        x: 0; y: root.height - height
        width: root.width; height: 28 * root.px
        pal: root; px: root.px
        kind: "thin-raised"

        Bevel {
            x: 4 * root.px; y: 3 * root.px
            width: 160 * root.px; height: 21 * root.px
            pal: root; px: root.px
            kind: "thin-sunken"
            fill: root.face
            PixelArt {
                x: 3 * root.px; y: (parent.height - height) / 2
                cell: root.px
                rows: root.keyArtSmall
                colors: root.iconColors
            }
            Text {
                x: 22 * root.px
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 24 * root.px
                text: "Welcome to Matrix 95"
                elide: Text.ElideRight
                color: root.ink
                font.family: root.mono
                font.pixelSize: root.fontPx
                font.bold: true
            }
        }

        Bevel {
            id: tray
            width: Math.max(72 * root.px, clockText.implicitWidth + 16 * root.px)
            height: 21 * root.px
            x: parent.width - width - 4 * root.px; y: 3 * root.px
            pal: root; px: root.px
            kind: "thin-sunken"
            fill: root.face
            Text {
                id: clockText
                anchors.centerIn: parent
                color: root.ink
                font.family: root.mono
                font.pixelSize: root.fontPx
                text: Qt.formatTime(new Date(), "HH:mm")
                Timer {
                    interval: 1000; repeat: true; running: true
                    onTriggered: clockText.text = Qt.formatTime(new Date(), "HH:mm")
                }
            }
        }
    }

    // ---- modal "Shut Down Matrix 95" dialog ----
    Item {
        id: shutLayer
        anchors.fill: parent
        visible: root.shutOpen
        z: 50

        Rectangle { anchors.fill: parent; color: Qt.rgba(root.bg.r, root.bg.g, root.bg.b, 0.6) }
        MouseArea { anchors.fill: parent }   // swallow clicks

        Item {
            id: shutDialog
            property int choice: 0           // 0 shut down, 1 restart, 2 suspend
            width: 330 * root.px
            height: 188 * root.px
            x: Math.round((parent.width - width) / 2)
            y: Math.round((parent.height - 28 * root.px - height) / 2)
            focus: true
            Keys.onEscapePressed: root.closeShutdown()

            Rectangle {
                x: 3 * root.px; y: 3 * root.px
                width: parent.width; height: parent.height
                color: Qt.rgba(0, 0, 0, 0.55)
            }
            Bevel {
                anchors.fill: parent
                pal: root; px: root.px
                kind: "raised"

                TitleBar {
                    x: 2 * root.px; y: 2 * root.px
                    width: parent.width - 4 * root.px
                    pal: root; px: root.px
                    text: "Shut Down Matrix 95"
                    onCloseClicked: root.closeShutdown()
                }

                PixelArt {
                    x: 14 * root.px; y: 40 * root.px
                    cell: root.px
                    rows: root.monitorArt
                    colors: root.monitorColors
                }
                Text {
                    x: 62 * root.px; y: 36 * root.px
                    text: "Are you sure you want to:"
                    color: root.ink
                    font.family: root.mono
                    font.pixelSize: root.fontPx
                }

                Column {
                    x: 62 * root.px; y: 58 * root.px
                    spacing: 6 * root.px
                    Repeater {
                        model: [
                            { label: "Shut down the computer?", ok: sddm.canPowerOff },
                            { label: "Restart the computer?",   ok: sddm.canReboot },
                            { label: "Suspend the computer?",   ok: sddm.canSuspend }
                        ]
                        delegate: Item {
                            id: radio
                            required property var modelData
                            required property int index
                            visible: modelData.ok
                            height: modelData.ok ? 18 * root.px : 0
                            width: 250 * root.px
                            readonly property bool selected: shutDialog.choice === index
                            activeFocusOnTab: modelData.ok
                            Keys.onPressed: (e) => {
                                if (e.key === Qt.Key_Space) { shutDialog.choice = index; e.accepted = true }
                                else if (e.key === Qt.Key_Down || e.key === Qt.Key_Up) {
                                    var d = e.key === Qt.Key_Down ? 1 : -1, n = index
                                    for (var i = 0; i < 3; i++) {
                                        n = (n + d + 3) % 3
                                        if ([sddm.canPowerOff, sddm.canReboot, sddm.canSuspend][n]) break
                                    }
                                    shutDialog.choice = n
                                    e.accepted = true
                                } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                                    shutDialog.choice = index; root.doShutdown(); e.accepted = true
                                }
                            }
                            onActiveFocusChanged: if (activeFocus) shutDialog.choice = index

                            // sunken round button
                            Rectangle {
                                id: dish
                                width: 12 * root.px; height: 12 * root.px
                                anchors.verticalCenter: parent.verticalCenter
                                radius: width / 2
                                color: root.bg
                                border.width: root.px
                                border.color: root.hilite
                                Rectangle {
                                    visible: radio.selected
                                    anchors.centerIn: parent
                                    width: 4 * root.px; height: 4 * root.px
                                    radius: width / 2
                                    color: root.head
                                }
                            }
                            Text {
                                id: radioText
                                x: 20 * root.px
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.label
                                color: root.ink
                                font.family: root.mono
                                font.pixelSize: root.fontPx
                            }
                            Dotted {
                                visible: radio.activeFocus
                                x: 17 * root.px; y: 1 * root.px
                                width: radioText.implicitWidth + 6 * root.px; height: parent.height - 2 * root.px
                                dot: root.ink; px: root.px
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: { shutDialog.choice = radio.index; radio.forceActiveFocus() }
                            }
                        }
                    }
                }

                PushButton {
                    id: yesButton
                    x: parent.width - 2 * 78 * root.px - 16 * root.px - 8 * root.px
                    y: parent.height - 25 * root.px - 14 * root.px
                    width: 78 * root.px; height: 25 * root.px
                    pal: root; px: root.px
                    text: "Yes"
                    isDefault: true
                    onClicked: root.doShutdown()
                    KeyNavigation.tab: noButton
                    KeyNavigation.backtab: noButton
                }
                PushButton {
                    id: noButton
                    x: parent.width - 78 * root.px - 16 * root.px
                    y: yesButton.y
                    width: 78 * root.px; height: 25 * root.px
                    pal: root; px: root.px
                    text: "No"
                    onClicked: root.closeShutdown()
                    KeyNavigation.tab: yesButton
                    KeyNavigation.backtab: yesButton
                }
            }
        }
    }

    Component.onCompleted: intro.start()
}
