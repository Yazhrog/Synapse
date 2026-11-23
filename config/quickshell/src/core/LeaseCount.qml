import QtQuick

// LeaseCount — the counter behind a service's `watched` flag.
//
// A service that only needs to work (poll, monitor) while something shows its
// data embeds one and forwards to it:
//
//   readonly property bool watched: _leases.watched
//   function acquire() { _leases.acquire() }
//   function release() { _leases.release() }
//   property LeaseCount _leases: LeaseCount {}
//
// Views hold a Lease on the service instead of the service reading UI state.
QtObject {
    readonly property bool watched: count > 0
    property int count: 0

    function acquire() { count++ }
    function release() { count = Math.max(0, count - 1) }
}
