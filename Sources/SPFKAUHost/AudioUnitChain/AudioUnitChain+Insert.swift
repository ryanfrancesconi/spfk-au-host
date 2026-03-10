// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

import AVFoundation
import Foundation
import SPFKUtils

extension AudioUnitChain {
    /// Loads a complete effects chain from an array of effect descriptions, replacing any existing effects.
    @discardableResult
    public func load(chainDescription: [AudioEffectDescription]) async throws -> [Error?] {
        //
        guard chainDescription.isNotEmpty else {
            try await removeEffects()
            return []
        }

        var errors = await [Error?](repeating: nil, count: data.insertCount)

        for desc in chainDescription {
            guard let index = desc.index, errors.indices.contains(index) else {
                Log.error("invalid index in", desc)
                continue
            }

            errors[index] = try await insertAudioUnit(effectDescription: desc, reconnectChain: false, at: index)

            try await bypassEffect(at: index, isBypassed: desc.isBypassed, reconnectChain: false)
        }

        try await connect()

        return errors
    }

    /// Inserts an audio unit from an effect description at the given index, applying any saved state.
    @discardableResult
    public func insertAudioUnit(
        effectDescription: AudioEffectDescription,
        reconnectChain: Bool = true,
        at index: Int
    ) async throws -> Error? {
        guard let componentDescription = effectDescription.componentDescription else {
            throw NSError(description: "Failed to create AudioComponentDescription")
        }

        // Insert the AU inside the actor, no AVAudioUnit escapes
        try await insertAudioUnit(componentDescription: componentDescription, at: index)

        // Apply full state internally by index, still within the actor
        if let fullState = effectDescription.fullStateDictionary {
            if let effect = try await data.effect(at: index) {
                effect.avAudioUnit.auAudioUnit.fullState = fullState
            }
        }

        return nil
    }

    /// Create the Audio Unit at the specified index of the chain
    public func insertAudioUnit(
        componentDescription: AudioComponentDescription,
        reconnectChain: Bool = true,
        at index: Int
    ) async throws {
        try await data.check(index: index)

        await delegate?.audioUnitChain(self, event: .willInsert(index: index))

        let ctype = componentDescription.componentType

        var audioUnit: AVAudioUnit?

        switch ctype {
        case kAudioUnitType_Effect, kAudioUnitType_MusicEffect, kAudioUnitType_FormatConverter:
            if let value = try? await Self.createEffect(
                componentDescription: componentDescription
            ) {
                audioUnit = value
            }

        case kAudioUnitType_MusicDevice, kAudioUnitType_Generator:
            if let value = try? await Self.createInstrument(
                componentDescription: componentDescription
            ) {
                audioUnit = value
            }

        default:
            throw NSError(description: "Unsupported component type of \(ctype) \(ctype.fourCC)")
        }

        guard let audioUnit else {
            throw NSError(description: "Failed to create audio unit from \(componentDescription)")
        }

        try await insert(audioUnit: audioUnit, at: index)

        if reconnectChain {
            try await connect()
        }

        await delegate?.audioUnitChain(self, event: .didInsert(index: index))
    }

    private func insert(audioUnit: AVAudioUnit, at index: Int) async throws {
        // if it has inputs, verify it supports stereo
        if audioUnit.numberOfInputs > 0 {
            guard audioUnit.inputFormat(forBus: 0).channelCount > 1 else {
                throw NSError(description: "\(audioUnit.name) is a Mono effect. Please select a stereo version of it.")
            }
        }

        let desc = AudioUnitDescription(avAudioUnit: audioUnit)

        try await update(
            audioUnit: desc,
            at: index
        )

        Log.debug("* Audio Unit created at index \(index): \(desc.name ?? "")")
    }

    private func update(audioUnit: AudioUnitDescription, at index: Int) async throws {
        if try await data.effect(at: index) != nil {
            try await removeEffect(at: index, reconnectChain: true, sendEvent: true)
            try await Task.sleep(seconds: 0.5) // hack
        }

        try await data.assign(audioUnitDescription: audioUnit, to: index)
    }
}
