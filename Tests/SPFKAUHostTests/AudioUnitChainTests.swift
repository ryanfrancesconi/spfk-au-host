// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

import AVFoundation
import Foundation
import SPFKAUHost
import SPFKBase
import SPFKTesting
import Testing

final class AudioUnitChainTests: TestCaseModel {
    let audioUnitChain: AudioUnitChain
    let dummyEngine = AudioUnitTestContent()

    init() async throws {
        audioUnitChain = .init(delegate: dummyEngine)

        // assign dummy IO
        let input = AVAudioPlayerNode()
        let output = AVAudioMixerNode()

        try await audioUnitChain.updateIO(input: input, output: output)
    }

    @Test func insert() async throws {
        try await audioUnitChain.insertAudioUnit(componentDescription: AudioUnitTestContent.auDelayDesc, at: 0)
        try await audioUnitChain.insertAudioUnit(componentDescription: AudioUnitTestContent.auMatrixReverbDesc, at: 1)
        try await audioUnitChain.insertAudioUnit(componentDescription: AudioUnitTestContent.auFilterDesc, at: 2)
        try await audioUnitChain.connect()

        await #expect(audioUnitChain.data.unbypassedEffects.count == 3)

        await print(audioUnitChain.connectionDescription)
    }

    @Test func insertOutOfBounds() async throws {
        await #expect(throws: (any Error).self) {
            try await audioUnitChain.insertAudioUnit(
                componentDescription: AudioUnitTestContent.auDelayDesc, at: audioUnitChain.insertCount + 1
            )
        }
    }

    // MARK: - Chain Resize

    @Test func appendInsert() async throws {
        let initialCount = await audioUnitChain.data.insertCount
        await audioUnitChain.appendInsert()
        let newCount = await audioUnitChain.data.insertCount
        #expect(newCount == initialCount + 1)
        let chainInsertCount = await audioUnitChain.insertCount
        #expect(chainInsertCount == newCount)
    }

    @Test func removeLastInsert() async throws {
        await audioUnitChain.appendInsert()
        let countAfterAppend = await audioUnitChain.data.insertCount
        try await audioUnitChain.removeLastInsert()
        let countAfterRemove = await audioUnitChain.data.insertCount
        #expect(countAfterRemove == countAfterAppend - 1)
        let chainInsertCount = await audioUnitChain.insertCount
        #expect(chainInsertCount == countAfterRemove)
    }

    @Test func removeLastInsertAtMinimumThrows() async {
        await #expect(throws: (any Error).self) {
            try await audioUnitChain.removeLastInsert()
        }
    }

    @Test func appendThenInsertAtNewIndex() async throws {
        await audioUnitChain.appendInsert()
        let newIndex = await audioUnitChain.insertCount - 1

        try await audioUnitChain.insertAudioUnit(
            componentDescription: AudioUnitTestContent.auDelayDesc, at: newIndex
        )

        let effect = try await audioUnitChain.data.effect(at: newIndex)
        #expect(effect != nil)
    }
}
