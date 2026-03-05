// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

import AudioToolbox

/// Notifies audio unit parameter listeners of state changes.
///
/// Useful after loading a preset so that any attached UI (e.g. an audio unit editor)
/// updates to reflect the new parameter values.
public enum AudioUnitStateNotifier {
    /// Broadcasts a parameter-value-change event for every global-scope parameter on the audio unit.
    ///
    /// Call this after setting an audio unit's full state so that registered
    /// `AUEventListener` instances refresh their displays.
    /// - Parameter audioUnit: The `AudioUnit` whose listeners should be notified.
    /// - Returns: The `OSStatus` from the last Core Audio call, or `noErr` on success.
    @discardableResult
    public static func notifyListeners(of audioUnit: AudioUnit) -> OSStatus {
        var parameter = AudioUnitParameter(
            mAudioUnit: audioUnit,
            mParameterID: kAUParameterListener_AnyParameter,
            mScope: kAudioUnitScope_Global,
            mElement: 0
        )
        return AUParameterListenerNotify(nil, nil, &parameter)
    }

    /// Loads a named factory preset into the audio unit.
    ///
    /// Retrieves the list of factory presets, finds the one matching `name`,
    /// sets it as the current preset, and notifies parameter listeners.
    /// - Parameters:
    ///   - audioUnit: The `AudioUnit` to load the preset into.
    ///   - name: The preset name to search for (case-sensitive).
    /// - Returns: `noErr` on success, or an appropriate `OSStatus` error code.
    @discardableResult
    public static func loadFactoryPreset(audioUnit: AudioUnit, named name: String) -> OSStatus {
        var unmanagedArray: Unmanaged<CFArray>?
        var dataSize = UInt32(MemoryLayout<Unmanaged<CFArray>?>.size)

        var status = AudioUnitGetProperty(
            audioUnit,
            kAudioUnitProperty_FactoryPresets,
            kAudioUnitScope_Global,
            0,
            &unmanagedArray,
            &dataSize
        )

        guard status == noErr, let presets = unmanagedArray?.takeRetainedValue() else {
            return status != noErr ? status : kAudioUnitErr_InvalidPropertyValue
        }

        let count = CFArrayGetCount(presets)
        var matchIndex = -1

        for i in 0 ..< count {
            let presetPtr = CFArrayGetValueAtIndex(presets, i)
            let preset = presetPtr!.assumingMemoryBound(to: AUPreset.self).pointee

            guard let presetName = preset.presetName?.takeUnretainedValue() as String? else {
                continue
            }
            if presetName == name {
                matchIndex = i
                break
            }
        }

        guard matchIndex >= 0 else {
            return kAudioUnitErr_InvalidPropertyValue
        }

        let matchedPtr = CFArrayGetValueAtIndex(presets, matchIndex)!
        let matched = matchedPtr.assumingMemoryBound(to: AUPreset.self)

        status = AudioUnitSetProperty(
            audioUnit,
            kAudioUnitProperty_PresentPreset,
            kAudioUnitScope_Global,
            0,
            matched,
            UInt32(MemoryLayout<AUPreset>.size)
        )

        if status == noErr {
            var parameter = AudioUnitParameter(
                mAudioUnit: audioUnit,
                mParameterID: kAUParameterListener_AnyParameter,
                mScope: kAudioUnitScope_Global,
                mElement: 0
            )
            AUParameterListenerNotify(nil, nil, &parameter)
        }

        return status
    }
}
