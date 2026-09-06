pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    // =========================================================================
    // PipeWire Sink Tracking & Availability
    // =========================================================================

    readonly property var _sink: Pipewire.defaultAudioSink

    // True only when PipeWire daemon is ready, sink is resolved, and audio controls are active
    readonly property bool available: Boolean(Pipewire.ready && _sink !== null && _sink.ready && _sink.audio !== null)

    // Current linear volume normalized strictly in [0.0, 1.0]; 0.0 if unavailable
    readonly property real volume: available ? (_sink?.audio?.volume ?? 0.0) : 0.0

    // Mute state; false if unavailable
    readonly property bool muted: available ? (_sink?.audio?.muted ?? false) : false

    // Human-readable audio sink name/description
    readonly property string sinkName: available ? (_sink?.description || _sink?.name || "") : ""

    // =========================================================================
    // PipeWire Source Tracking & Availability (Microphone)
    // =========================================================================

    readonly property var _source: Pipewire.defaultAudioSource

    // True only when PipeWire daemon is ready, source is resolved, and audio controls are active
    readonly property bool micAvailable: Boolean(Pipewire.ready && _source !== null && _source.ready && _source.audio !== null)

    // Current linear mic volume normalized strictly in [0.0, 1.0]; 0.0 if unavailable
    readonly property real micVolume: micAvailable ? (_source?.audio?.volume ?? 0.0) : 0.0

    // Mic mute state; false if unavailable
    readonly property bool micMuted: micAvailable ? (_source?.audio?.muted ?? false) : false

    // Human-readable audio source name/description
    readonly property string sourceName: micAvailable ? (_source?.description || _source?.name || "") : ""

    // Track default audio sink properties reactively via Quickshell PipeWire tracker
    PwObjectTracker {
        objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
    }

    // Track default audio source properties reactively via Quickshell PipeWire tracker
    PwObjectTracker {
        objects: Pipewire.defaultAudioSource ? [Pipewire.defaultAudioSource] : []
    }

    // =========================================================================
    // Public Methods
    // =========================================================================

    // Sets master volume with strict boundary clamping [0.0, 1.0]
    function setVolume(target: real): void {
        if (!root.available || !root._sink || !root._sink.audio) {
            return;
        }
        const clamped = Math.max(0.0, Math.min(1.0, target));
        root._sink.audio.volume = clamped;
    }

    // Relative volume adjustment (e.g. from mouse wheel scroll events).
    // Safely delegates to clamped setVolume; un-mutes automatically on positive delta.
    function stepVolume(delta: real): void {
        if (!root.available) {
            return;
        }
        if (root.muted && delta > 0 && root._sink && root._sink.audio) {
            root._sink.audio.muted = false;
        }
        root.setVolume(root.volume + delta);
    }

    // Inverts mute state on the default audio sink
    function toggleMute(): void {
        if (!root.available || !root._sink || !root._sink.audio) {
            return;
        }
        root._sink.audio.muted = !root._sink.audio.muted;
    }

    // =========================================================================
    // Public Microphone Methods
    // =========================================================================

    // Sets microphone volume with strict boundary clamping [0.0, 1.0]
    function setMicVolume(target: real): void {
        if (!root.micAvailable || !root._source || !root._source.audio) {
            return;
        }
        const clamped = Math.max(0.0, Math.min(1.0, target));
        root._source.audio.volume = clamped;
    }

    // Relative mic volume adjustment (e.g. from mouse wheel scroll events).
    // Safely delegates to clamped setMicVolume; un-mutes automatically on positive delta.
    function stepMicVolume(delta: real): void {
        if (!root.micAvailable) {
            return;
        }
        if (root.micMuted && delta > 0 && root._source && root._source.audio) {
            root._source.audio.muted = false;
        }
        root.setMicVolume(root.micVolume + delta);
    }

    // Inverts mute state on the default audio source
    function toggleMicMute(): void {
        if (!root.micAvailable || !root._source || !root._source.audio) {
            return;
        }
        root._source.audio.muted = !root._source.audio.muted;
    }
}

