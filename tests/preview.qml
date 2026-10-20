// Offscreen preview: renders the rain for a few seconds and saves a PNG.
// Usage: QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
//   qml tests/preview.qml -- <out.png> <bg> <ink> <head> <dim>
import QtQuick
import QtQuick.Window
import "../rain"

Window {
    id: win
    width: 960
    height: 540
    visible: true
    color: "black"

    readonly property var args: Qt.application.arguments.slice(Qt.application.arguments.indexOf("--") + 1)

    MatrixRain {
        id: rain
        anchors.fill: parent
        backgroundColor: win.args[1]
        inkColor: win.args[2]
        headColor: win.args[3]
        dimColor: win.args[4]
        glyphSize: 16
        running: win.args[5] !== "static"
    }

    Timer {
        interval: 4500
        running: true
        onTriggered: rain.grabToImage(function (result) {
            result.saveToFile(win.args[0])
            Qt.quit()
        })
    }
}
