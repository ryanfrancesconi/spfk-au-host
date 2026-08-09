// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

import Foundation
import SPFKAudioBase
import SPFKBase

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

extension AudioUnitInsertSnapshot {
    /// The persistable form of this slot. Window placement belongs to the UI layer and is
    /// not captured here, so a caller that has it must fill those fields in.
    public var insert: AudioUnitInsert {
        AudioUnitInsert(
            uid: uid,
            index: index,
            isBypassed: isBypassed,
            name: name,
            fullStatePlistData: fullStatePlistData
        )
    }
}

extension AudioUnitChain {
    /// Captures the current chain state as a `Sendable` snapshot.
    public func snapshot() async -> AudioUnitChainSnapshot {
        await data.snapshot()
    }

    /// Reinstates a saved chain: resizes the slot array to `insertCount`, then loads the inserts.
    ///
    /// Returns each slot's failure at its own index — see `load(inserts:)`.
    @discardableResult
    public func restore(insertCount: Int, inserts: [AudioUnitInsert]) async throws -> [Error?] {
        let currentCount = await data.insertCount

        if insertCount > currentCount {
            for _ in currentCount ..< insertCount {
                await appendInsert()
            }

        } else if insertCount < currentCount {
            for _ in insertCount ..< currentCount {
                do {
                    try await removeLastInsert()
                } catch {
                    // Occupied or already at the minimum. An extra empty slot is cosmetic and
                    // must not cost the caller the inserts that follow.
                    Log.debug("Stopped shrinking chain:", error)
                    break
                }
            }
        }

        return try await load(inserts: inserts)
    }

    /// Reinstates a chain captured by `snapshot()`.
    @discardableResult
    public func restore(_ snapshot: AudioUnitChainSnapshot) async throws -> [Error?] {
        try await restore(insertCount: snapshot.insertCount, inserts: snapshot.inserts.map(\.insert))
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
