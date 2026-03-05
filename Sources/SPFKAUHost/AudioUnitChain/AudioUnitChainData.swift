// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

import AVFoundation
import Foundation
import SPFKBase

/// Actor managing the fixed-size effects slot array for an ``AudioUnitChain``.
///
/// Each slot in ``effectsChain`` is either `nil` (empty) or contains an ``AudioUnitDescription``
/// wrapping an `AVAudioUnit`. Methods validate slot indices and throw on out-of-bounds access.
public actor AudioUnitChainData {
    /// The fixed-size array of effect slots. `nil` entries are empty slots.
    public private(set) var effectsChain: [AudioUnitDescription?]

    /// The total number of slots (occupied and empty) in the chain.
    public var insertCount: Int { effectsChain.count }

    /// A non-nil variable-length array of Audio Units that are currently in the chain.
    public var linkedEffects: [AudioUnitDescription] {
        effectsChain.compactMap(\.self)
    }

    /// Effects that are neither bypassed nor lacking I/O support.
    public var unbypassedEffects: [AudioUnitDescription] {
        linkedEffects.filter {
            !$0.isBypassed && $0.audioComponentDescription.supportsIO
        }
    }

    /// The `AUAudioUnit` instances from ``unbypassedEffects``.
    public var unbypassedAUAudioUnits: [AUAudioUnit] {
        unbypassedEffects.compactMap(\.avAudioUnit.auAudioUnit)
    }

    /// How many effects are active (occupied slots).
    public var effectsCount: Int { linkedEffects.count }

    /// Creates a chain data instance with `insertCount` empty slots.
    public init(insertCount: Int) {
        effectsChain = [AudioUnitDescription?](repeating: nil, count: insertCount)
    }

    /// Returns the effect at the given slot index, or `nil` if the slot is empty.
    public func effect(at index: Int) throws -> AudioUnitDescription? {
        try check(index: index)
        return effectsChain[index]
    }

    /// Assigns an ``AudioUnitDescription`` to the given slot index.
    public func assign(audioUnitDescription: AudioUnitDescription, to index: Int) throws {
        try check(index: index)
        effectsChain[index] = audioUnitDescription
    }

    /// The combined latency of all unbypassed effects in the chain.
    public var totalLatency: TimeInterval {
        unbypassedEffects.compactMap(\.avAudioUnit.latency).reduce(0, +)
    }

    /// Returns the latency of the effect at the given slot index.
    public func latency(at index: Int) throws -> TimeInterval {
        try check(index: index)
        return try effect(at: index)?.avAudioUnit.latency ?? 0
    }

    /// Returns whether the effect at the given slot index is bypassed.
    public func isBypassed(at index: Int) throws -> Bool {
        try check(index: index)
        return effectsChain[index]?.isBypassed == true
    }

    /// Bypasses the effect at the given slot index.
    public func bypass(index: Int) throws {
        try check(index: index)
        effectsChain[index]?.isBypassed = true
    }

    /// Enables (un-bypasses) the effect at the given slot index.
    public func enable(index: Int) throws {
        try check(index: index)
        effectsChain[index]?.isBypassed = false
    }

    /// Disposes and removes all effects from the chain.
    public func removeAll() throws {
        for i in 0 ..< effectsChain.count {
            try remove(index: i)
        }
    }

    /// Disposes and removes the effect at the given slot index.
    public func remove(index: Int) throws {
        try check(index: index)
        try effectsChain[index]?.dispose()
        effectsChain[index] = nil
    }

    /// Sets the `AUAudioUnit.contextName` for the effect at the given slot index.
    public func setContextName(at index: Int, string: String?) throws {
        try check(index: index)
        effectsChain[index]?.avAudioUnit.auAudioUnit.contextName = string
    }

    /// Moves an effect from one slot to another, preserving its bypass state.
    public func moveEffect(from startIndex: Int, to endIndex: Int) throws {
        try check(index: startIndex)
        try check(index: endIndex)

        guard let auAudioUnit = effectsChain[startIndex]?.avAudioUnit.auAudioUnit else { return }

        let bypassState = effectsChain[startIndex]?.isBypassed == true

        if !bypassState {
            effectsChain[startIndex]?.isBypassed = true
        }

        auAudioUnit.reset()

        let element = effectsChain.remove(at: startIndex)
        effectsChain.insert(element, at: endIndex)

        effectsChain[endIndex]?.isBypassed = bypassState
    }
}

extension AudioUnitChainData {
    /// Resets all linked Audio Units, clearing any buffered processing state.
    public func resetAudioUnits() {
        for item in linkedEffects {
            item.avAudioUnit.reset()
        }
    }

    /// Allocates render resources for any unbypassed AUs that haven't yet allocated them.
    public func allocateRenderResourcesIfNeeded() async {
        for au in unbypassedAUAudioUnits where !au.renderResourcesAllocated {
            do {
                Log.debug("*AU allocateRenderResources for", au.audioUnitName)
                try au.allocateRenderResources()

            } catch {
                Log.error(error)
            }
        }
    }

    /// Assigns host musical context and transport state blocks to all unbypassed AUs,
    /// then allocates render resources if needed.
    public func update(hostAUState: HostAUState) async {
        for au in unbypassedAUAudioUnits {
            if au.musicalContextBlock == nil {
                Log.debug("*AU Setting musicalContextBlock for", au.audioUnitName)
                au.musicalContextBlock = hostAUState.musicalContextBlock
            }

            if au.transportStateBlock == nil {
                Log.debug("*AU Setting transportStateBlock for", au.audioUnitName)
                au.transportStateBlock = hostAUState.transportStateBlock
            }
        }

        await allocateRenderResourcesIfNeeded()
    }
}

extension AudioUnitChainData {
    /// Validates that the given index is within bounds of the effects chain.
    public func check(index: Int) throws {
        guard effectsChain.indices.contains(index) else { throw indexError(index: index) }
    }

    private func indexError(index: Int) -> NSError {
        NSError(description: "Invalid index requested: \(index)")
    }
}
