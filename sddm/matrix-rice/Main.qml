// Matrix Rice SDDM login theme (Qt 6).
// Uses only plain QtQuick plus SDDM's context objects: sddm, userModel,
// sessionModel and config (values from theme.conf). MatrixRain.qml and
// MatrixGlow.qml are copied next to this file at install time.

import QtQuick

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: config.background

    readonly property color ink: config.ink
    readonly property color head: config.head
    readonly property color dim: config.dim
    readonly property color faint: config.faint
    readonly property color surface: config.surface
    readonly property color alert: config.alert
    readonly property string mono: config.font || "monospace"
    readonly property int unit: Math.max(14, Math.round(Math.min(width, height) / 60))

    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property bool busy: false

    function tryLogin() {
        if (userField.text.length === 0) {
            userField.forceActiveFocus()
            return
        }
        busy = true
        status.text = "> authenticating..."
        status.color = root.dim
        sddm.login(userField.text, passwordField.text, root.sessionIndex)
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.busy = false
            passwordField.text = ""
            passwordField.forceActiveFocus()
            status.text = "> access denied. try again."
            status.color = root.alert
            shake.restart()
        }
        function onLoginSucceeded() {
            status.text = "> access granted"
            status.color = root.ink
        }
    }

    MatrixRain {
        anchors.fill: parent
        backgroundColor: config.background
        inkColor: config.ink
        headColor: config.head
        dimColor: config.dim
        glow: String(config.glow) !== "false"
        glyphSize: Math.round(root.unit * 1.1)
        density: 0.6
    }

    // Login box
    Rectangle {
        id: box
        width: Math.min(root.width - root.unit * 4, root.unit * 30)
        height: column.implicitHeight + root.unit * 3
        anchors.centerIn: parent
        color: Qt.rgba(root.surface.r, root.surface.g, root.surface.b, 0.92)
        border.color: root.ink
        border.width: 1

        SequentialAnimation on anchors.horizontalCenterOffset {
            id: shake
            running: false
            NumberAnimation { to: -12; duration: 50 }
            NumberAnimation { to: 12; duration: 70 }
            NumberAnimation { to: -8; duration: 70 }
            NumberAnimation { to: 0; duration: 50 }
        }

        Column {
            id: column
            anchors.centerIn: parent
            width: parent.width - root.unit * 3
            spacing: root.unit * 0.8

            Text {
                text: "MATRIX // " + (sddm.hostName || "localhost").toUpperCase()
                color: root.ink
                font.family: root.mono
                font.pixelSize: root.unit * 1.1
                font.bold: true
                font.letterSpacing: 2
            }

            Text {
                id: clock
                color: root.head
                font.family: root.mono
                font.pixelSize: root.unit * 2.6
                text: Qt.formatDateTime(new Date(), "HH:mm:ss")
                Timer {
                    interval: 1000
                    repeat: true
                    running: true
                    onTriggered: clock.text = Qt.formatDateTime(new Date(), "HH:mm:ss")
                }
            }

            Text {
                text: Qt.formatDate(new Date(), "dddd, d MMMM yyyy").toLowerCase()
                color: root.dim
                font.family: root.mono
                font.pixelSize: root.unit * 0.8
            }

            Item { width: 1; height: root.unit * 0.4 }

            // ---- username ----
            Text {
                text: "login:"
                color: root.dim
                font.family: root.mono
                font.pixelSize: root.unit * 0.8
            }
            Rectangle {
                width: parent.width
                height: root.unit * 2
                color: root.color
                border.color: userField.activeFocus ? root.ink : root.faint
                border.width: 1
                TextInput {
                    id: userField
                    anchors.fill: parent
                    anchors.leftMargin: root.unit * 0.6
                    anchors.rightMargin: root.unit * 0.6
                    verticalAlignment: TextInput.AlignVCenter
                    color: root.ink
                    selectionColor: root.ink
                    selectedTextColor: root.color
                    font.family: root.mono
                    font.pixelSize: root.unit
                    text: userModel.lastUser
                    clip: true
                    KeyNavigation.tab: passwordField
                    onAccepted: passwordField.forceActiveFocus()
                }
            }

            // ---- password ----
            Text {
                text: "password:"
                color: root.dim
                font.family: root.mono
                font.pixelSize: root.unit * 0.8
            }
            Rectangle {
                width: parent.width
                height: root.unit * 2
                color: root.color
                border.color: passwordField.activeFocus ? root.ink : root.faint
                border.width: 1
                TextInput {
                    id: passwordField
                    anchors.fill: parent
                    anchors.leftMargin: root.unit * 0.6
                    anchors.rightMargin: root.unit * 0.6
                    verticalAlignment: TextInput.AlignVCenter
                    color: root.ink
                    selectionColor: root.ink
                    selectedTextColor: root.color
                    font.family: root.mono
                    font.pixelSize: root.unit
                    echoMode: TextInput.Password
                    passwordCharacter: "*"
                    clip: true
                    enabled: !root.busy
                    KeyNavigation.backtab: userField
                    KeyNavigation.tab: userField
                    onAccepted: root.tryLogin()
                    Keys.onEscapePressed: text = ""
                }
            }

            // ---- session picker: < Plasma (Wayland) > ----
            Row {
                spacing: root.unit * 0.5
                visible: sessionList.count > 1

                Text {
                    text: "session:"
                    color: root.dim
                    font.family: root.mono
                    font.pixelSize: root.unit * 0.8
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "<"
                    color: prevArea.containsMouse ? root.head : root.ink
                    font.family: root.mono
                    font.pixelSize: root.unit
                    MouseArea {
                        id: prevArea
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        onClicked: root.sessionIndex = (root.sessionIndex + sessionList.count - 1) % sessionList.count
                    }
                }
                ListView {
                    id: sessionList
                    width: column.width - root.unit * 8
                    height: root.unit * 1.4
                    model: sessionModel
                    orientation: ListView.Horizontal
                    interactive: false
                    clip: true
                    currentIndex: root.sessionIndex
                    highlightMoveDuration: 0
                    highlightRangeMode: ListView.StrictlyEnforceRange
                    preferredHighlightBegin: 0
                    preferredHighlightEnd: width
                    delegate: Text {
                        required property string name
                        width: sessionList.width
                        text: name
                        elide: Text.ElideRight
                        color: root.ink
                        font.family: root.mono
                        font.pixelSize: root.unit * 0.9
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
                Text {
                    text: ">"
                    color: nextArea.containsMouse ? root.head : root.ink
                    font.family: root.mono
                    font.pixelSize: root.unit
                    MouseArea {
                        id: nextArea
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        onClicked: root.sessionIndex = (root.sessionIndex + 1) % sessionList.count
                    }
                }
            }

            Text {
                id: status
                width: parent.width
                text: "> enter password and press Enter"
                color: root.dim
                font.family: root.mono
                font.pixelSize: root.unit * 0.8
                wrapMode: Text.Wrap
            }
        }
    }

    // ---- power buttons ----
    Row {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: root.unit * 2
        spacing: root.unit * 2

        Repeater {
            model: [
                { label: "[ suspend ]", show: sddm.canSuspend, act: function () { sddm.suspend() } },
                { label: "[ reboot ]", show: sddm.canReboot, act: function () { sddm.reboot() } },
                { label: "[ shut down ]", show: sddm.canPowerOff, act: function () { sddm.powerOff() } }
            ]
            delegate: Text {
                required property var modelData
                visible: modelData.show
                text: modelData.label
                color: area.containsMouse ? root.head : root.ink
                font.family: root.mono
                font.pixelSize: root.unit * 0.85
                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: parent.modelData.act()
                }
            }
        }
    }

    Component.onCompleted: {
        if (userField.text.length > 0)
            passwordField.forceActiveFocus()
        else
            userField.forceActiveFocus()
    }
}
