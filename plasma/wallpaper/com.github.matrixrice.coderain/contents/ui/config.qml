// Settings page shown in "Configure Desktop and Wallpaper" and in the
// lock screen settings. Colors are not here on purpose: they follow the
// active variant set by `matrix-rice green|cyan|amber`.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: root
    twinFormLayouts: parentLayout

    property alias formLayout: root
    property alias cfg_Animated: animated.checked
    property alias cfg_Glow: glow.checked
    property alias cfg_Speed: speed.value
    property alias cfg_Density: density.value
    property alias cfg_GlyphSize: glyphSize.value
    property alias cfg_Fps: fps.value

    QQC2.CheckBox {
        id: animated
        Kirigami.FormData.label: "Live rain:"
        text: "Animate (off shows a still frame)"
    }

    QQC2.CheckBox {
        id: glow
        Kirigami.FormData.label: "Glow:"
        text: "Soft bloom (drawn by the graphics chip)"
    }

    RowLayout {
        Kirigami.FormData.label: "Speed:"
        QQC2.Slider {
            id: speed
            from: 0.3
            to: 3.0
            stepSize: 0.1
            Layout.preferredWidth: Kirigami.Units.gridUnit * 12
        }
        QQC2.Label { text: speed.value.toFixed(1) + "x" }
    }

    RowLayout {
        Kirigami.FormData.label: "Density:"
        QQC2.Slider {
            id: density
            from: 0.1
            to: 1.0
            stepSize: 0.05
            Layout.preferredWidth: Kirigami.Units.gridUnit * 12
        }
        QQC2.Label { text: Math.round(density.value * 100) + "%" }
    }

    QQC2.SpinBox {
        id: glyphSize
        Kirigami.FormData.label: "Character size:"
        from: 8
        to: 64
    }

    QQC2.SpinBox {
        id: fps
        Kirigami.FormData.label: "Frame rate cap:"
        from: 10
        to: 60
    }

    QQC2.Label {
        Layout.maximumWidth: Kirigami.Units.gridUnit * 22
        wrapMode: Text.WordWrap
        opacity: 0.7
        text: "Colors follow the active variant. Switch in a terminal with: matrix-rice green, matrix-rice cyan or matrix-rice amber"
    }
}
