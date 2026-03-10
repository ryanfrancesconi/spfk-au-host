// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

import AEXML
import AudioToolbox
@preconcurrency import AVFoundation
import Foundation
import SPFKUtils

/// Manages loading and locating audio unit presets, including user presets on disk.
public enum AudioUnitPresets {
    // MARK: Create Preset XML

    /// convenience used by for embedding full state in project XML
    public static func fullStateDocument(for avAudioUnit: AVAudioUnit) -> AEXMLDocument? {
        guard let state = avAudioUnit.auAudioUnit.fullState else { return nil }
        return try? PlistUtilities.dictionaryToPlist(dictionary: state)
    }

    /// Loads a preset from an XML element into the audio unit, returning the parsed full state dictionary.
    @discardableResult
    public static func loadPreset(for avAudioUnit: AVAudioUnit, element: AEXMLElement) async -> [String: Any]? {
        guard let fullState = try? PlistUtilities.plistToDictionary(element: element) else {
            return nil
        }

        await loadPreset(for: avAudioUnit, fullState: fullState)

        return fullState
    }

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
