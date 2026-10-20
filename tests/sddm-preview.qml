// Offscreen preview of the SDDM theme with stand-in SDDM objects.
// Main.qml is loaded by a Loader, so it can see the ids below the same way
// it sees SDDM's real context objects.
// Usage: qml tests/sddm-preview.qml -- <out.png> <theme-dir> <bg> <surface> <ink> <head> <dim> <faint> <alert> [fail]
import QtQuick
import QtQuick.Window

Window {
    id: win
    width: 1280
    height: 720
    visible: true

    readonly property var args: Qt.application.arguments.slice(Qt.application.arguments.indexOf("--") + 1)

    QtObject {
        id: config
        property string background: win.args[2]
        property string surface: win.args[3]
        property string ink: win.args[4]
        property string head: win.args[5]
        property string dim: win.args[6]
        property string faint: win.args[7]
        property string alert: win.args[8]
        property string font: "JetBrains Mono"
        property string glow: "true"
    }
    QtObject {
        id: sddm
        property string hostName: "loq"
        property bool canSuspend: true
        property bool canReboot: true
        property bool canPowerOff: true
        signal loginFailed()
        signal loginSucceeded()
        function login(u, p, s) { loginFailed() }
        function suspend() {}
        function reboot() {}
        function powerOff() {}
    }
    ListModel {
        id: sessionModel
        property int lastIndex: 0
        ListElement { name: "Plasma (Wayland)" }
        ListElement { name: "Plasma (X11)" }
    }
    QtObject {
        id: userModel
        property string lastUser: "neo"
    }

    Loader {
        id: loader
        anchors.fill: parent
        source: "file://" + win.args[1] + "/Main.qml"
        onStatusChanged: if (status === Loader.Error) Qt.exit(3)
    }

    Timer {
        interval: 3500
        running: true
        onTriggered: {
            if (win.args[9] === "fail") sddm.login("neo", "x", 0)
            snap.start()
        }
    }
    Timer {
        id: snap
        interval: 600
        onTriggered: loader.item.grabToImage(function (r) { r.saveToFile(win.args[0]); Qt.quit() })
    }
}
