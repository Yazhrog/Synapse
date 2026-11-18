import QtQuick
import qs.src.components.settings
import qs.src.services.data
// PrefTextField — a SettingsTextField bound to the pref `key`: label,
// description and default from PrefSchema; the placeholder defaults to the
// default value.
SettingsTextField {
    required property string key

    readonly property var _schema: PrefSchema.keys[key] ?? ({})
    label:           _schema.label ?? key
    description:     _schema.description ?? ""
    placeholderText: String(_schema.default ?? "")
    value:           Prefs.data[key]
    defaultValue:    _schema.default
    onEdited:         v => Prefs.set(key, v)
    onResetRequested: Prefs.reset(key)
}
