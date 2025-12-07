// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

import AVFoundation
import Foundation
import SPFKAUHost
import SPFKBase
import SPFKTesting
import Testing

final class AudioUnitChainTests: TestCaseModel {
    let audioUnitChain: AudioUnitChain
    let dummyEngine = DummyEngine()

    init() async throws {
        audioUnitChain = .init(delegate: dummyEngine)

        // assign dummy IO
        let input = AVAudioPlayerNode()
        let output = AVAudioMixerNode()

        try await audioUnitChain.updateIO(input: input, output: output)
    }

    @Test func findEffects() async throws {
        #expect(dummyEngine.components.count == 2)
    }

    @Test func insert() async throws {
        try await audioUnitChain.insertAudioUnit(componentDescription: dummyEngine.auDelayDesc, at: 0)
        try await audioUnitChain.insertAudioUnit(componentDescription: dummyEngine.auMatrixReverbDesc, at: 1)
        try await audioUnitChain.connect()

        await #expect(audioUnitChain.data.unbypassedEffects.count == 2)
        
        print(await audioUnitChain.connectionDescription)

    }

    @Test func insertOutOfBounds() async throws {
        await #expect(throws: (any Error).self) {
            try await audioUnitChain.insertAudioUnit(
                componentDescription: dummyEngine.auDelayDesc, at: audioUnitChain.insertCount + 1
            )
        }
    }
}
