// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

import AVFoundation
import Foundation
import SPFKAUHost
import SPFKBase
import SPFKTesting
import Testing

final class AudioUnitChainTests: TestCaseModel {
    let audioUnitChain: AudioUnitChain
    let dummyEngine = TestAudioUnitContent()

    init() async throws {
        audioUnitChain = .init(delegate: dummyEngine)

        // assign dummy IO
        let input = AVAudioPlayerNode()
        let output = AVAudioMixerNode()

        try await audioUnitChain.updateIO(input: input, output: output)
    }

    @Test func insert() async throws {
        try await audioUnitChain.insertAudioUnit(componentDescription: TestAudioUnitContent.auDelayDesc, at: 0)
        try await audioUnitChain.insertAudioUnit(componentDescription: TestAudioUnitContent.auMatrixReverbDesc, at: 1)
        try await audioUnitChain.insertAudioUnit(componentDescription: TestAudioUnitContent.auFilterDesc, at: 2)
        try await audioUnitChain.connect()

        await #expect(audioUnitChain.data.unbypassedEffects.count == 3)

        await print(audioUnitChain.connectionDescription)
    }

    @Test func insertOutOfBounds() async throws {
        await #expect(throws: (any Error).self) {
            try await audioUnitChain.insertAudioUnit(
                componentDescription: TestAudioUnitContent.auDelayDesc, at: audioUnitChain.insertCount + 1
            )
        }
    }
}
