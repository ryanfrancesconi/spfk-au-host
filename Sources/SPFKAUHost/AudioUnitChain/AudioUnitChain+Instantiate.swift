// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

import AudioToolbox
import AVFoundation
import SPFKBase

extension AudioUnitChain {
    /// Returns whether an audio component matching the given description is available on the system.
    public static func isAvailable(componentDescription: AudioComponentDescription) -> Bool {
        AVAudioUnitComponent.component(matching: componentDescription) != nil
    }

    /// Will attempt to create an out of process effect first and if that fails will
    /// return an in process.
    public static func createEffect(
        componentDescription: AudioComponentDescription
    ) async throws -> AVAudioUnit? {
        //
        guard isAvailable(componentDescription: componentDescription) else {
            return nil
        }

        // Try .loadOutOfProcess first
        if let value = try? await createEffect(
            componentDescription: componentDescription,
            options: .loadOutOfProcess
        ) {
            return value
        }

        #if macOS
            let options: AudioComponentInstantiationOptions = .loadInProcess

        #else
            let options: AudioComponentInstantiationOptions = []
        #endif

        if let value = try await Self.createEffect(
            componentDescription: componentDescription,
            options: options
        ) {
            return value
        }

        return nil
    }

    /// Creates an effect audio unit with the specified instantiation options.
    public static func createEffect(
        componentDescription: AudioComponentDescription,
        options: AudioComponentInstantiationOptions
    ) async throws -> AVAudioUnit? {
        try await AVAudioUnit.instantiate(
            with: componentDescription,
            options: options
        )
    }

    /// Creates a MIDI instrument audio unit from the given component description.
    public static func createInstrument(
        componentDescription: AudioComponentDescription
    ) async throws -> AVAudioUnitMIDIInstrument? {
        try await createEffect(componentDescription: componentDescription) as? AVAudioUnitMIDIInstrument
    }

    /// Creates a MIDI instrument audio unit with the specified instantiation options.
    public static func createInstrument(
        componentDescription: AudioComponentDescription,
        options: AudioComponentInstantiationOptions
    ) async throws -> AVAudioUnitMIDIInstrument? {
        try await createEffect(componentDescription: componentDescription, options: options) as? AVAudioUnitMIDIInstrument
    }
}
