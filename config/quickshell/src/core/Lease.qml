import QtQuick

// Lease — asks a service to stay active while `active` is true.
//
//   Lease { service: VpnService; active: Popups.networkOpen }
//
// Calls service.acquire() when it becomes active and service.release() when
// it stops being active, changes service or is destroyed, so a count can't
// leak. The service side is a LeaseCount.
QtObject {
    id: root

    property var  service: null
    property bool active:  false

    property var _held: null   // the service this lease currently holds

    function _sync() {
        const want = active ? service : null
        if (want === _held) return
        if (_held) _held.release()
        _held = want
        if (_held) _held.acquire()
    }

    onActiveChanged:  _sync()
    onServiceChanged: _sync()
    Component.onCompleted:   _sync()
    Component.onDestruction: if (_held) _held.release()
}
