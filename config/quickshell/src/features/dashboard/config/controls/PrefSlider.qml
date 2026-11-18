import QtQuick
import qs.src.components.settings
import qs.src.services.data
// PrefSlider — a SettingsSlider bound to the pref `key`: label,
// description, range (min/max) and default from PrefSchema.
SettingsSlider {
    required property string key

    readonly property var _schema: PrefSchema.keys[key] ?? ({})
    label:        _schema.label ?? key
    description:  _schema.description ?? ""
    from:         _schema.min ?? 0
    to:           _schema.max ?? 100
    value:        Prefs.data[key]
    defaultValue: _schema.default
    onEdited:         v => Prefs.set(key, v)
    onResetRequested: Prefs.reset(key)
}
