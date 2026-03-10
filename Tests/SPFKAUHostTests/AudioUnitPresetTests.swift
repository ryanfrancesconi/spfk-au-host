// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

import AudioToolbox
import AVFoundation
import Testing

@testable import SPFKAUHost

/// Drains the run loop briefly so that any pending async event-listener
/// callbacks dispatched by `AUParameterListenerNotify` can fire while the
/// `AVAudioUnit` is still alive. Without this the V2Bridge's internal
/// event listener can dereference a deallocated parameter tree.
private func drainRunLoop() async {
    try? await Task.sleep(for: .milliseconds(50))
}

// MARK: - AudioUnitStateNotifier

struct AudioUnitStateNotifierTests {
    static let auDelayDesc = AudioComponentDescription(
        componentType: kAudioUnitType_Effect,
        componentSubType: 0x6465_6C79, // 'dely' - AUDelay
        componentManufacturer: kAudioUnitManufacturer_Apple,
        componentFlags: 0,
        componentFlagsMask: 0
    )

    static let auReverbDesc = AudioComponentDescription(
        componentType: kAudioUnitType_Effect,
        componentSubType: kAudioUnitSubType_MatrixReverb,
        componentManufacturer: kAudioUnitManufacturer_Apple,
        componentFlags: 0,
        componentFlagsMask: 0
    )

    @Test func notifyListenersReturnsNoErr() async throws {
        let avAudioUnit = try await AVAudioUnit.instantiate(
            with: AudioUnitTestContent.auDelayDesc,
            options: []
        )
        let status = AudioUnitStateNotifier.notifyListeners(of: avAudioUnit.audioUnit)
        #expect(status == noErr)
        await drainRunLoop()
    }

    @Test func notifyListenersOnAUWithParameters() async throws {
        let avAudioUnit = try await AVAudioUnit.instantiate(
            with: AudioUnitTestContent.auDelayDesc,
            options: []
        )

        // Verify the AU has parameters (sanity check)
        let parameterTree = avAudioUnit.auAudioUnit.parameterTree
        #expect(parameterTree != nil)
        #expect((parameterTree?.allParameters.count ?? 0) > 0)

        let status = AudioUnitStateNotifier.notifyListeners(of: avAudioUnit.audioUnit)
        #expect(status == noErr)
        await drainRunLoop()
    }

    @Test func loadFactoryPresetSucceeds() async throws {
        let avAudioUnit = try await AVAudioUnit.instantiate(
            with: Self.auReverbDesc,
            options: []
        )

        let factoryPresets = avAudioUnit.auAudioUnit.factoryPresets ?? []
        try #require(!factoryPresets.isEmpty, "AUMatrixReverb should have factory presets")

        let presetName = factoryPresets[0].name

        let status = AudioUnitStateNotifier.loadFactoryPreset(
            audioUnit: avAudioUnit.audioUnit,
            named: presetName
        )
        #expect(status == noErr)
        await drainRunLoop()
    }

    @Test func loadFactoryPresetWithInvalidNameFails() async throws {
        let avAudioUnit = try await AVAudioUnit.instantiate(
            with: AudioUnitTestContent.auDelayDesc,
            options: []
        )

        let status = AudioUnitStateNotifier.loadFactoryPreset(
            audioUnit: avAudioUnit.audioUnit,
            named: "NonexistentPreset_12345"
        )
        // No factory presets on AUDelay, so this should fail
        #expect(status != noErr)
    }

    @Test func loadFactoryPresetChangesState() async throws {
        let avAudioUnit = try await AVAudioUnit.instantiate(
            with: Self.auReverbDesc,
            options: []
        )

        let factoryPresets = avAudioUnit.auAudioUnit.factoryPresets ?? []
        try #require(factoryPresets.count >= 2, "Need at least 2 factory presets")

        // Load first preset
        let status1 = AudioUnitStateNotifier.loadFactoryPreset(
            audioUnit: avAudioUnit.audioUnit,
            named: factoryPresets[0].name
        )
        #expect(status1 == noErr)

        let stateAfterFirst = avAudioUnit.auAudioUnit.fullState

        // Load second preset
        let status2 = AudioUnitStateNotifier.loadFactoryPreset(
            audioUnit: avAudioUnit.audioUnit,
            named: factoryPresets[1].name
        )
        #expect(status2 == noErr)

        let stateAfterSecond = avAudioUnit.auAudioUnit.fullState

        // States should differ between presets
        #expect(stateAfterFirst != nil)
        #expect(stateAfterSecond != nil)

        // The present preset name should reflect the second preset
        let currentPreset = avAudioUnit.auAudioUnit.currentPreset
        #expect(currentPreset?.name == factoryPresets[1].name)
        await drainRunLoop()
    }
}

// MARK: - AudioUnitPresets

struct AudioUnitPresetsTests {
    @Test func fullStateDocumentReturnsXML() async throws {
        let avAudioUnit = try await AVAudioUnit.instantiate(
            with: AudioUnitTestContent.auDelayDesc,
            options: []
        )

        let document = AudioUnitPresets.fullStateDocument(for: avAudioUnit)
        #expect(document != nil)

        // The XML should contain plist content
        let xml = document?.xml
        #expect(xml?.contains("plist") == true)
    }

    @Test func loadPresetFromFullState() async throws {
        let avAudioUnit = try await AVAudioUnit.instantiate(
            with: AudioUnitTestContent.auDelayDesc,
            options: []
        )

        // Capture the default full state
        guard let originalState = avAudioUnit.auAudioUnit.fullState else {
            Issue.record("AUDelay should have a full state")
            return
        }

        // Modify a parameter to change the state
        if let delayTime = avAudioUnit.auAudioUnit.parameterTree?.allParameters.first {
            delayTime.value = delayTime.minValue
        }

        // Load the original state back (this calls notifyListeners internally)
        await AudioUnitPresets.loadPreset(for: avAudioUnit, fullState: originalState)

        // Verify state was restored
        let restoredState = avAudioUnit.auAudioUnit.fullState
        #expect(restoredState != nil)
        await drainRunLoop()
    }

    @Test func fullStateRoundTrip() async throws {
        let avAudioUnit = try await AVAudioUnit.instantiate(
            with: AudioUnitTestContent.auDelayDesc,
            options: []
        )

        // Get XML document from current state
        let document = AudioUnitPresets.fullStateDocument(for: avAudioUnit)
        try #require(document != nil)

        // Modify a parameter
        if let param = avAudioUnit.auAudioUnit.parameterTree?.allParameters.first {
            param.value = param.minValue
        }

        // Load state back from XML element (this calls notifyListeners internally)
        let restored = await AudioUnitPresets.loadPreset(for: avAudioUnit, element: document!.root)
        #expect(restored != nil)
        await drainRunLoop()
    }

    @Test func factoryPresetsReturnsArray() async throws {
        let avAudioUnit = try await AVAudioUnit.instantiate(
            with: AudioUnitTestContent.auDynamicsProcessorDesc,
            options: []
        )

        let presets = avAudioUnit.auAudioUnit.factoryPresets
        #expect(presets?.isNotEmpty == true)
    }

    @Test func supportsUserPresets() async throws {
        let avAudioUnit = try await AVAudioUnit.instantiate(
            with: AudioUnitTestContent.auDynamicsProcessorDesc,
            options: []
        )

        #expect(avAudioUnit.auAudioUnit.supportsUserPresets)

        let presets = avAudioUnit.auAudioUnit.userPresets
        #expect(presets.isNotEmpty)
    }
}
