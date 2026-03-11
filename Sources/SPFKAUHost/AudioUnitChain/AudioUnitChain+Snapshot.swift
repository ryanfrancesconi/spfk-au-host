// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

import Foundation
import SPFKAudioBase

/// A `Sendable` snapshot of a single audio unit insert slot,
/// safe to pass across actor boundaries.
public struct AudioUnitInsertSnapshot: Sendable {
    /// The hex UID identifying the audio component.
    public let uid: String

    /// The slot index in the effects chain.
    public let index: Int

    /// Whether this insert is bypassed.
    public let isBypassed: Bool

    /// The resolved display name.
    public let name: String?

    /// The full AU state serialized as property list XML `Data`.
    public let fullStatePlistData: Data?
}

/// A `Sendable` snapshot of the full audio unit chain state.
public struct AudioUnitChainSnapshot: Sendable {
    /// The total number of insert slots (including empty ones).
    public let insertCount: Int

    /// Snapshots of occupied slots only.
    public let inserts: [AudioUnitInsertSnapshot]
}

extension AudioUnitChain {
    /// Captures the current chain state as a `Sendable` snapshot.
    public func snapshot() async -> AudioUnitChainSnapshot {
        await data.snapshot()
    }
}

extension AudioUnitChainData {
    /// Captures all occupied slots as a `Sendable` snapshot.
    func snapshot() -> AudioUnitChainSnapshot {
        let inserts: [AudioUnitInsertSnapshot] = effectsChain.enumerated().compactMap { index, slot in
            guard let slot else { return nil }

            var plistData: Data?
            if let fullState = slot.avAudioUnit.auAudioUnit.fullState {
                plistData = try? PropertyListSerialization.data(
                    fromPropertyList: fullState,
                    format: .xml,
                    options: 0
                )
            }

            return AudioUnitInsertSnapshot(
                uid: slot.audioComponentDescription.uid,
                index: index,
                isBypassed: slot.isBypassed,
                name: slot.name,
                fullStatePlistData: plistData
            )
        }

        return AudioUnitChainSnapshot(
            insertCount: insertCount,
            inserts: inserts
        )
    }
}
