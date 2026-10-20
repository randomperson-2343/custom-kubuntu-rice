// MatrixRain.qml - shared Matrix code rain engine.
// Pure Qt Quick (no Plasma imports) so the same file runs in the desktop
// wallpaper, the lock screen and the SDDM login screen.
//
// Technique: every frame the whole canvas is dimmed slightly toward the
// background color, then each column draws only its new head glyph. The
// dimming produces the fading trail; an "eraser" at the end of each trail
// wipes the faint leftovers that 8-bit color rounding would otherwise leave.

import QtQuick
import QtQuick.Window

Item {
    id: rain

    property color backgroundColor: "#030A04"
    property color inkColor: "#00FF41"
    property color headColor: "#D8FFE0"
    property color dimColor: "#008F11"

    property bool running: true
    property real speed: 1.0      // multiplier on the base fall speed
    property real density: 0.75   // 0..1, share of columns that rain at once
    property int glyphSize: 18    // logical pixels per cell
    property int fps: 30
    property int trail: 26        // trail length in rows
    property string fontFamily: "Noto Sans Mono CJK JP"
    property bool glow: true      // GPU bloom layer (needs QtQuick.Effects)

    // Half-width katakana, digits and a few symbols, like the film.
    readonly property string glyphs: "ｦｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾗﾘﾙﾚﾛﾜﾝ0123456789Z:.\"=*+-<>|"
    readonly property real dpr: Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1
    readonly property real baseRowsPerSecond: 13

    Rectangle {
        anchors.fill: parent
        color: rain.backgroundColor
    }

    Canvas {
        id: canvas

        // Draw at physical resolution, then scale down, so glyphs stay
        // sharp on scaled (HiDPI) screens.
        width: Math.max(1, Math.ceil(rain.width * rain.dpr))
        height: Math.max(1, Math.ceil(rain.height * rain.dpr))
        scale: 1 / rain.dpr
        transformOrigin: Item.TopLeft
        renderStrategy: Canvas.Cooperative

        property var drops: []
        property int cols: 0
        property int rows: 0
        property real cell: 1
        property bool needsReset: true

        onWidthChanged: needsReset = true
        onHeightChanged: needsReset = true
        onPaint: rain.frame(getContext("2d"))
    }

    // Bloom: a blurred copy of the rain drawn by the GPU behind nothing but
    // itself, blended on top at low opacity. Lives in its own file and is
    // loaded on demand, so a missing QtQuick.Effects module only disables
    // the glow instead of breaking the whole wallpaper.
    Loader {
        anchors.fill: parent
        active: rain.glow
        source: "MatrixGlow.qml"
        onLoaded: item.source = canvas
    }

    Timer {
        interval: Math.max(8, Math.round(1000 / Math.max(1, rain.fps)))
        repeat: true
        running: rain.running && rain.visible && rain.width > 0 && rain.height > 0
        onTriggered: canvas.requestPaint()
    }

    onBackgroundColorChanged: restart()
    onInkColorChanged: restart()
    onHeadColorChanged: restart()
    onGlyphSizeChanged: restart()
    onDensityChanged: restart()
    onSpeedChanged: restart()
    onFpsChanged: restart()
    onTrailChanged: restart()
    onRunningChanged: if (!running) restart()
    Component.onCompleted: restart()

    // Clear and refill. When rain is switched off, pre-run enough frames
    // to leave a full still image instead of an empty screen.
    function restart() {
        canvas.needsReset = true
        canvas.requestPaint()
    }

    function avgRowsPerFrame() {
        // Column speeds are base * (0.45 .. 1.25), average 0.85.
        return baseRowsPerSecond * speed * 0.85 / Math.max(1, fps)
    }

    function rgba(c, a) {
        return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + a + ")"
    }

    function randomGlyph() {
        return glyphs.charAt(Math.floor(Math.random() * glyphs.length))
    }

    function newDrop(stagger) {
        return {
            y: -Math.random() * canvas.rows * (stagger ? 1.0 : 0.6),
            v: baseRowsPerSecond * speed * (0.45 + Math.random() * 0.8) / Math.max(1, fps),
            row: -1000000,
            ch: randomGlyph(),
            mirror: Math.random() < 0.25,
            active: Math.random() < density
        }
    }

    function drawCell(ctx, col, row, color, ch, mirror) {
        var c = canvas.cell
        var x = col * c
        var y = row * c
        ctx.fillStyle = backgroundColor.toString()
        ctx.fillRect(x, y, c, c)
        ctx.fillStyle = color
        if (mirror) {
            ctx.save()
            ctx.translate(x + c, y)
            ctx.scale(-1, 1)
            ctx.fillText(ch, c * 0.1, c * 0.05)
            ctx.restore()
        } else {
            ctx.fillText(ch, x + c * 0.1, y + c * 0.05)
        }
    }

    function eraseCell(ctx, col, row) {
        var c = canvas.cell
        ctx.fillStyle = backgroundColor.toString()
        ctx.fillRect(col * c, row * c, c, c)
    }

    function reset(ctx) {
        canvas.cell = Math.max(4, Math.round(glyphSize * dpr))
        canvas.cols = Math.ceil(canvas.width / canvas.cell)
        canvas.rows = Math.ceil(canvas.height / canvas.cell)
        var d = []
        for (var i = 0; i < canvas.cols; i++)
            d.push(newDrop(true))
        canvas.drops = d
        ctx.globalAlpha = 1
        ctx.fillStyle = backgroundColor.toString()
        ctx.fillRect(0, 0, canvas.width, canvas.height)
        canvas.needsReset = false
    }

    function step(ctx, fadeStyle, fontStr) {
        var rows = canvas.rows
        var drops = canvas.drops
        var ink = inkColor.toString()
        var head = headColor.toString()

        ctx.fillStyle = fadeStyle
        ctx.fillRect(0, 0, canvas.width, canvas.height)
        ctx.font = fontStr

        for (var i = 0; i < drops.length; i++) {
            var d = drops[i]
            d.y += d.v
            var row = Math.floor(d.y)
            if (row !== d.row) {
                var from = Math.max(d.row, row - trail - 1)
                for (var r = from + 1; r <= row; r++) {
                    if (!d.active)
                        continue
                    // Old head becomes normal ink, new cell gets a fresh glyph.
                    if (r - 1 >= 0 && r - 1 < rows)
                        drawCell(ctx, i, r - 1, ink, d.ch, d.mirror)
                    d.ch = randomGlyph()
                    d.mirror = Math.random() < 0.25
                    var tail = r - trail
                    if (tail >= 0 && tail < rows)
                        eraseCell(ctx, i, tail)
                }
                d.row = row
            }
            if (d.active && row >= 0 && row < rows)
                drawCell(ctx, i, row, head, d.ch, d.mirror)
            if (row - trail > rows)
                drops[i] = newDrop(false)
        }

        // Flicker: a few glyphs inside live trails change character.
        var flickers = Math.ceil(drops.length * 0.04)
        var dim = dimColor.toString()
        for (var f = 0; f < flickers; f++) {
            var k = Math.floor(Math.random() * drops.length)
            var fd = drops[k]
            if (!fd.active)
                continue
            var fr = fd.row - 2 - Math.floor(Math.random() * trail * 0.5)
            if (fr >= 0 && fr < rows && fr > fd.row - trail)
                drawCell(ctx, k, fr, dim, randomGlyph(), Math.random() < 0.25)
        }
    }

    function frame(ctx) {
        var n = 1
        if (canvas.needsReset) {
            reset(ctx)
            if (!running)
                n = Math.ceil((canvas.rows + trail) / Math.max(0.001, avgRowsPerFrame()))
        }
        // Fade so a glyph drops to ~4% brightness over one trail length.
        var framesPerTrail = trail / Math.max(0.001, avgRowsPerFrame())
        var alpha = 1 - Math.pow(0.04, 1 / Math.max(1, framesPerTrail))
        var fadeStyle = rgba(backgroundColor, alpha.toFixed(4))
        var fontStr = "bold " + Math.round(canvas.cell * 0.9) + "px '" + fontFamily + "'"
        ctx.textBaseline = "top"
        for (var i = 0; i < n; i++)
            step(ctx, fadeStyle, fontStr)
    }
}
