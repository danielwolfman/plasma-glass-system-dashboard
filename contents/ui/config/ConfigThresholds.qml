import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: page

    property alias cfg_backgroundOpacity: backgroundOpacity.value
    property alias cfg_cardOpacity: cardOpacity.value
    property alias cfg_showAccentGlow: accentGlow.checked
    property alias cfg_warningLevel: warningSpin.value
    property alias cfg_criticalLevel: criticalSpin.value

    Kirigami.FormLayout {
        Controls.Slider {
            id: backgroundOpacity
            Kirigami.FormData.label: i18n("Widget background:")
            from: 0
            to: 100
            stepSize: 5
            snapMode: Controls.Slider.SnapAlways
        }

        Controls.Label {
            text: Math.round(backgroundOpacity.value) + "%"
            Kirigami.FormData.label: i18n("Background opacity:")
        }

        Controls.Slider {
            id: cardOpacity
            Kirigami.FormData.label: i18n("Card opacity:")
            from: 0
            to: 100
            stepSize: 5
            snapMode: Controls.Slider.SnapAlways
        }

        Controls.Label {
            text: Math.round(cardOpacity.value) + "%"
            Kirigami.FormData.label: i18n("Current card opacity:")
        }

        Controls.CheckBox {
            id: accentGlow
            Kirigami.FormData.label: i18n("Decoration:")
            text: i18n("Show blue accent glow")
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
        }

        Controls.SpinBox {
            id: warningSpin
            Kirigami.FormData.label: i18n("Warning level:")
            from: 1
            to: 99
            editable: true
            textFromValue: function(value) { return value + "%" }
            valueFromText: function(text) { return parseInt(text) }
        }

        Controls.SpinBox {
            id: criticalSpin
            Kirigami.FormData.label: i18n("Critical level:")
            from: 2
            to: 100
            editable: true
            textFromValue: function(value) { return value + "%" }
            valueFromText: function(text) { return parseInt(text) }
        }

        Controls.Label {
            Kirigami.FormData.label: i18n("Colors:")
            text: i18n("Values turn yellow at the warning level and red at the critical level. Temperature thresholds are fixed at 75°C and 90°C.")
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }
}
