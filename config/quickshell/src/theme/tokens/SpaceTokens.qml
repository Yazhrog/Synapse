import QtQuick

// SpaceTokens — Theme.space (ARCHITECTURE.md §5.12): the spacing scale for
// margins, paddings and spacings. Literal spacings move here in v0.8.0's
// per-area passes (decision D1), where content scaling (#79) multiplies them.
//
// Instantiated by Theme only.
QtObject {
    readonly property int xxs: 2
    readonly property int xs:  4
    readonly property int sm:  6
    readonly property int md:  8
    readonly property int lg:  12
    readonly property int xl:  16
    readonly property int xxl: 24
}
