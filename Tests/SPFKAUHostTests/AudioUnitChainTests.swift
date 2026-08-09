// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

import AVFoundation
import Foundation
import SPFKAudioBase
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

    // MARK: - Restore

    /// A component that parses as a UID but resolves to no installed audio unit: `aufx/zzzz/appl`.
    /// The subtype must not be zero — Core Audio reads that as a wildcard and matches the first
    /// effect the manufacturer ships.
    static let unknownUID = "617566787a7a7a7a6170706c"

    @Test func loadContinuesPastAFailedSlot() async throws {
        let unknown = AudioUnitInsert(uid: Self.unknownUID, index: 0, isBypassed: false)
        let delay = AudioUnitInsert(uid: AudioUnitTestContent.auDelayDesc.uid, index: 1, isBypassed: false)

        let errors = try await audioUnitChain.load(inserts: [unknown, delay])

        #expect(errors[0] != nil)
        #expect(errors[1] == nil)

        let failedSlot = try await audioUnitChain.data.effect(at: 0)
        let loadedSlot = try await audioUnitChain.data.effect(at: 1)

        #expect(failedSlot == nil)
        #expect(loadedSlot != nil)
    }

    @Test func restoreGrowsTheChainToTheSavedInsertCount() async throws {
        let delay = AudioUnitInsert(uid: AudioUnitTestContent.auDelayDesc.uid, index: 5, isBypassed: false)

        try await audioUnitChain.restore(insertCount: 6, inserts: [delay])

        let count = await audioUnitChain.data.insertCount
        #expect(count == 6)

        let effect = try await audioUnitChain.data.effect(at: 5)
        #expect(effect != nil)
    }

    /// The graph rebuild path: a chain is captured, disposed with its track, and reinstated
    /// into the chain belonging to a freshly built one.
    @Test func snapshotRestoresIntoAFreshChain() async throws {
        try await audioUnitChain.insertAudioUnit(componentDescription: AudioUnitTestContent.auDelayDesc, at: 0)
        try await audioUnitChain.insertAudioUnit(componentDescription: AudioUnitTestContent.auFilterDesc, at: 2)
        try await audioUnitChain.bypassEffect(at: 2, isBypassed: true)

        let snapshot = await audioUnitChain.snapshot()
        #expect(snapshot.inserts.count == 2)

        let rebuilt = AudioUnitChain(delegate: dummyEngine)
        let input = AVAudioPlayerNode()
        let output = AVAudioMixerNode()
        try await rebuilt.updateIO(input: input, output: output)

        try await rebuilt.restore(snapshot)

        let effectsCount = await rebuilt.data.effectsCount
        #expect(effectsCount == 2)

        let names = await rebuilt.data.linkedEffects.compactMap(\.name)
        #expect(names == ["AUDelay", "AUFilter"])

        let isBypassed = try await rebuilt.data.isBypassed(at: 2)
        #expect(isBypassed)

        // Only the unbypassed effect is in the signal path.
        let unbypassed = await rebuilt.data.unbypassedEffects.count
        #expect(unbypassed == 1)
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
