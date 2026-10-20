// Offscreen preview of the KSplash theme. Loads a rendered Splash.qml (with
// MatrixRain.qml next to it), drives its `stage` property the way ksplashqml
// does, and grabs frames.
//
// Usage:
//   QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
//     qml tests/splash-preview.qml -- <splash-dir> <out> [still|gif|fade] [WxH]
//
// still  <out> is a PNG, grabbed ~3 s in (stage 4: logo up, bar scrolling).
// gif    <out> is a directory; frame-0000.png ... every 67 ms (15 fps, a 3.7 s loop with
//        the fade-in at the start and the stage-5 fade-out at the end), plus
//        times.txt with the real grab timestamps in ms.
// fade   <out> is a PNG grabbed mid fade-out (shows the stage 5 handling).
import QtQuick
import QtQuick.Window

Window {
    id: win
    visible: true
    color: "#000000"
    readonly property var args: Qt.application.arguments.slice(Qt.application.arguments.indexOf("--") + 1)
    readonly property string mode: args[2] || "still"
    readonly property string dims: args[3] || "1280x720"
    width: parseInt(dims.split("x")[0])
    height: parseInt(dims.split("x")[1])

    property int frame: 0
    property var stamps: []
    readonly property int frameMs: 67
    readonly property int totalFrames: 56
    readonly property int fadeFrame: 46   // stage 5 arrives at ~3.1 s

    Loader {
        id: loader
        anchors.fill: parent
        source: "file://" + win.args[0] + "/Splash.qml"
        onStatusChanged: if (status === Loader.Error) Qt.exit(3)
        onLoaded: item.stage = 2          // Wayland: initial + wm arrive together
    }

    // Stage ladder, like ksplashqml --test (one step per 2 s there, faster here).
    Timer { interval: 1000; running: win.mode === "still" || win.mode === "fade"; onTriggered: loader.item.stage = 3 }
    Timer { interval: 2000; running: win.mode === "still" || win.mode === "fade"; onTriggered: loader.item.stage = 4 }
    Timer { interval: 3500; running: win.mode === "fade"; onTriggered: loader.item.stage = 5 }
    Timer {
        interval: win.mode === "fade" ? 3750 : 3000
        running: win.mode !== "gif"
        onTriggered: loader.item.grabToImage(function (r) { r.saveToFile(win.args[1]); Qt.quit() })
    }

    // gif mode: one grab per tick
    Timer {
        id: gifTimer
        interval: win.frameMs
        repeat: true
        running: win.mode === "gif"
        onTriggered: {
            var n = win.frame++
            win.stamps.push(Date.now())
            if (n === 4) loader.item.stage = 3
            if (n === 20) loader.item.stage = 4
            if (n === win.fadeFrame) loader.item.stage = 5
            var name = win.args[1] + "/frame-" + ("0000" + n).slice(-4) + ".png"
            loader.item.grabToImage(function (r) { r.saveToFile(name) })
            if (win.frame >= win.totalFrames) {
                gifTimer.stop()
                finish.start()
            }
        }
    }
    Timer {
        id: finish
        interval: 400
        onTriggered: {
            var out = []
            for (var i = 0; i < win.stamps.length; i++) out.push(win.stamps[i] - win.stamps[0])
            console.log("STAMPS " + out.join(","))
            Qt.quit()
        }
    }
}
