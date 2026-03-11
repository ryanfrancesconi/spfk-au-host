// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

import AEXML
@preconcurrency import AVFoundation
import AudioToolbox
import SPFKBase

/// A wrapper for the `AVAudioUnit` to allow an independent bypass property
/// which doesn't rely on the `AUAudioUnit` one
public struct AudioUnitDescription: Equatable, Sendable {
    public static func == (lhs: AudioUnitDescription, rhs: AudioUnitDescription) -> Bool {
        lhs.avAudioUnit == rhs.avAudioUnit
    }

    /// The resolved display name of the audio unit.
    public let name: String?

    /// The underlying `AudioComponentDescription` identifying this audio unit's type, subtype, and manufacturer.
    public var audioComponentDescription: AudioComponentDescription {
        avAudioUnit.audioComponentDescription
    }

    private var _isBypassed = false

    /// Keep a bypassed flag separate from the audio units as they can be unreliable
    /// Test that, if it's true keep this class otherwise, make the array just [AVAudioUnit]
    public var isBypassed: Bool {
        get { _isBypassed }
        set {
            _isBypassed = newValue
            // the audio unit may or may not agree to this
            avAudioUnit.auAudioUnit.shouldBypassEffect = newValue
        }
    }

    /// The full state of the audio unit serialized as an XML plist element, if available.
    public var fullStatePlist: AEXMLElement? {
        AudioUnitPresets.fullStateDocument(for: avAudioUnit)?.root
    }

    /// The wrapped `AVAudioUnit` instance.
    public private(set) var avAudioUnit: AVAudioUnit

    /// Creates a new description wrapping the given `AVAudioUnit`.
    public init(avAudioUnit: AVAudioUnit) {
        self.avAudioUnit = avAudioUnit
        name = avAudioUnit.resolvedName
    }

    /// Releases resources by clearing context blocks and detaching the audio unit from the engine.
    public func dispose() throws {
        avAudioUnit.auAudioUnit.musicalContextBlock = nil
        avAudioUnit.auAudioUnit.transportStateBlock = nil
        try avAudioUnit.detach()
    }
}
