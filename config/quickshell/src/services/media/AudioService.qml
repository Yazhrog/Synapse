pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.src.core
// AudioService — the default output (sink) and input (source), their volume
// and mute, and the audio devices to pick them from, through Pipewire.
//
// The default sink and source are always tracked; every device node only
// while something holds a Lease (the audio popup's mixer lists them).
Singleton {
    id: root

    // ── State ───────────────────────────────────────────────────────────────
    readonly property var  sink:        Pipewire.defaultAudioSink
    readonly property var  source:      Pipewire.defaultAudioSource
    readonly property bool sinkReady:   sink?.ready ?? false
    readonly property bool sourceReady: source?.ready ?? false

    readonly property var sinkNodes:   _devices(true)    // hardware outputs
    readonly property var sourceNodes: _devices(false)   // hardware inputs

    function deviceName(node) {
        if (!node) return "Unknown"
        return node.nickname || node.description || node.name || "Unknown"
    }

    // ── Intents ─────────────────────────────────────────────────────────────
    function setVolume(v: real)       { if (sinkReady) sink.audio.volume = v }
    function toggleMute()             { if (sinkReady) sink.audio.muted = !sink.audio.muted }
    function setSourceVolume(v: real) { if (sourceReady) source.audio.volume = v }
    function toggleSourceMute()       { if (sourceReady) source.audio.muted = !source.audio.muted }
    function setDefaultSink(node)     { Pipewire.preferredDefaultAudioSink = node }
    function setDefaultSource(node)   { Pipewire.preferredDefaultAudioSource = node }

    // ── Lease: track every device node while a view lists them ──────────────
    readonly property bool watched: _leases.watched
    function acquire() { _leases.acquire() }
    function release() { _leases.release() }

    // ── Implementation ──────────────────────────────────────────────────────
    function _devices(sinks) {
        const out = []
        const nodes = Pipewire.nodes.values
        for (let i = 0; i < nodes.length; i++) {
            const n = nodes[i]
            if (n.audio !== null && !n.isStream && n.isSink === sinks) out.push(n)
        }
        return out
    }

    property LeaseCount _leases: LeaseCount {}

    property PwObjectTracker _defaults: PwObjectTracker {
        objects: [root.sink, root.source].filter(n => n)
    }

    property PwObjectTracker _all: PwObjectTracker {
        objects: root.watched ? Pipewire.nodes.values : []
    }
}
