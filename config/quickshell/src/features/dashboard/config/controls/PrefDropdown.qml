import QtQuick
import qs.src.components.settings
import qs.src.services.data
// PrefDropdown — a SettingsDropdown bound to the pref `key`: label,
// description, options and default from PrefSchema (a page can pass its own
// `options`, e.g. built from a registry).
SettingsDropdown {
    required property string key

    readonly property var _schema: PrefSchema.keys[key] ?? ({})
    label:        _schema.label ?? key
    description:  _schema.description ?? ""
    options:      _schema.options ?? []
    value:        Prefs.data[key]
    defaultValue: _schema.default
    onEdited:         v => Prefs.set(key, v)
    onResetRequested: Prefs.reset(key)
}
