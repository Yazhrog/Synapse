import QtQuick
import qs.src.components.settings
import qs.src.services.data
// PrefToggle — a SettingsToggle bound to the pref `key` (ARCHITECTURE.md
// §10.5): label, description and default from PrefSchema; writes through
// Prefs.set(). With `autoWrite: false` it only emits toggled() and the page
// writes the value itself (through a service with side effects).
SettingsToggle {
    required property string key
    property bool autoWrite: true

    readonly property var _schema: PrefSchema.keys[key] ?? ({})
    label:        _schema.label ?? key
    description:  _schema.description ?? ""
    value:        Prefs.data[key]
    defaultValue: _schema.default
    onEdited:         v => { if (autoWrite) Prefs.set(key, v) }
    onResetRequested: Prefs.reset(key)
}
