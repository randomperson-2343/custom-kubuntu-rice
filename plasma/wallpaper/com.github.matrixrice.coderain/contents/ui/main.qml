// Matrix Code Rain wallpaper. MatrixRain.qml and MatrixGlow.qml are copied
// next to this file from rain/ at install time.
import QtQuick
import org.kde.plasma.plasmoid

WallpaperItem {
    id: root

    MatrixRain {
        anchors.fill: parent
        backgroundColor: root.configuration.Background
        inkColor: root.configuration.Ink
        headColor: root.configuration.Head
        dimColor: root.configuration.Dim
        running: root.configuration.Animated
        glow: root.configuration.Glow
        speed: root.configuration.Speed
        density: root.configuration.Density
        glyphSize: root.configuration.GlyphSize
        fps: root.configuration.Fps
    }
}
