// MatrixGlow.qml - optional GPU bloom over MatrixRain's canvas.
import QtQuick
import QtQuick.Effects

MultiEffect {
    blurEnabled: true
    blurMax: 32
    blur: 0.6
    opacity: 0.55
}
