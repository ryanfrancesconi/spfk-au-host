// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

import AudioToolbox
@preconcurrency import AVFoundation
import Foundation
import SPFKBase
import SPFKUtils

/// Manages loading and locating audio unit presets, including user presets on disk.
public enum AudioUnitPresets {
    /// Applies the given full state dictionary to the audio unit and notifies listeners of the change.
    /// Runs the fullState assignment at default priority to avoid priority inversion with AUAudioUnit internals.
    public static func loadPreset(for avAudioUnit: AVAudioUnit, fullState: [String: Any]) async {
        // Dispatch at default QoS to avoid priority inversion — AUAudioUnit.fullState
        // setter internally synchronises on a Default-QoS thread.
        nonisolated(unsafe) let state = fullState
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .default).async {
                avAudioUnit.auAudioUnit.fullState = state
                continuation.resume()
            }
        }

        let status = AudioUnitStateNotifier.notifyListeners(of: avAudioUnit.audioUnit)

        guard noErr == status else {
            Log.error("notifyAudioUnitListener returned error:", status.fourCC)
            return
        }
    }
}
