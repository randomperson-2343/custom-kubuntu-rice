// Offscreen preview of the SDDM theme with stand-in SDDM objects.
// Main.qml is loaded by a Loader, so it can see the ids below the same way
// it sees SDDM's real context objects (config, sddm, sessionModel, userModel).
//
// Usage (the rendered theme.conf is read with XHR, which needs the env var):
//   QML_XHR_ALLOW_FILE_READ=1 QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
//     qml tests/sddm-preview.qml -- <out.png> <theme-dir> <theme.conf> [state] [WxH]
// state: "" (idle) | "fail" (failed login) | "shutdown" (Shut Down dialog open)
//        | "early" (grab mid-way through the dialog open animation)
import QtQuick
import QtQuick.Window

Window {
    id: win
    visible: true
    width: parseInt((args[4] || "1600x900").split("x")[0])
    height: parseInt((args[4] || "1600x900").split("x")[1])

    readonly property var args: Qt.application.arguments.slice(Qt.application.arguments.indexOf("--") + 1)
    readonly property string state_: args[3] || ""

    // Stand-in for SDDM's `config`: every key theme.conf can carry.
    QtObject {
        id: config
        property string background: "#000000"
        property string surface: "#000000"
        property string ink: "#00ff00"
        property string head: "#ffffff"
        property string dim: "#008000"
        property string faint: "#003000"
        property string alert: "#ff0000"
        property string face: ""
        property string hilite: ""
        property string light: ""
        property string shadow: ""
        property string dkshadow: ""
        property string title: ""
        property string titleinactive: ""
        property string titleinactivetext: ""
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

    Component.onCompleted: {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "file://" + args[2], false)
        xhr.send()
        var lines = xhr.responseText.split("\n")
        for (var i = 0; i < lines.length; i++) {
            var m = /^([a-z]+)=(.*)$/.exec(lines[i].trim())
            if (m && m[1] in config)
                config[m[1]] = m[2]
        }
        loader.active = true
    }

    Loader {
        id: loader
        active: false
        anchors.fill: parent
        source: "file://" + win.args[1] + "/Main.qml"
        onStatusChanged: if (status === Loader.Error) Qt.exit(3)
    }

    Timer {
        interval: win.state_ === "early" ? 400 : 2200
        running: true
        onTriggered: {
            if (win.state_ === "fail") sddm.login("neo", "x", 0)
            else if (win.state_ === "shutdown") loader.item.openShutdown()
            snap.start()
        }
    }
    Timer {
        id: snap
        interval: win.state_ === "early" ? 1 : 500
        onTriggered: loader.item.grabToImage(function (r) { r.saveToFile(win.args[0]); Qt.quit() })
    }
}
