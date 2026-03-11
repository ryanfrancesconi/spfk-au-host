import AVFoundation
import Foundation
import SPFKAUHost
import Testing

@testable import SPFKAUHost

struct AudioUnitChainDataTests {
    @Test func initWithInsertCount() async {
        let data = AudioUnitChainData(insertCount: 10)
        let count = await data.insertCount
        #expect(count == 10)
    }

    @Test func defaultInsertCount() async {
        let data = AudioUnitChainData(insertCount: AudioUnitChain.defaultInsertCount)
        let count = await data.insertCount
        #expect(count == 4)
    }

    @Test func effectsChainStartsEmpty() async {
        let data = AudioUnitChainData(insertCount: 3)
        let linked = await data.linkedEffects
        #expect(linked.isEmpty)
    }

    @Test func effectsCountStartsAtZero() async {
        let data = AudioUnitChainData(insertCount: 3)
        let count = await data.effectsCount
        #expect(count == 0)
    }

    @Test func unbypassedEffectsStartsEmpty() async {
        let data = AudioUnitChainData(insertCount: 3)
        let unbypassed = await data.unbypassedEffects
        #expect(unbypassed.isEmpty)
    }

    @Test func totalLatencyStartsAtZero() async {
        let data = AudioUnitChainData(insertCount: 3)
        let latency = await data.totalLatency
        #expect(latency == 0)
    }

    @Test func checkValidIndex() async throws {
        let data = AudioUnitChainData(insertCount: 3)
        try await data.check(index: 0)
        try await data.check(index: 2)
    }

    @Test func checkInvalidIndexThrows() async {
        let data = AudioUnitChainData(insertCount: 3)
        await #expect(throws: (any Error).self) {
            try await data.check(index: 3)
        }
    }

    @Test func checkNegativeIndexThrows() async {
        let data = AudioUnitChainData(insertCount: 3)
        await #expect(throws: (any Error).self) {
            try await data.check(index: -1)
        }
    }

    @Test func effectAtEmptySlotReturnsNil() async throws {
        let data = AudioUnitChainData(insertCount: 3)
        let effect = try await data.effect(at: 0)
        #expect(effect == nil)
    }

    @Test func effectAtInvalidIndexThrows() async {
        let data = AudioUnitChainData(insertCount: 3)
        await #expect(throws: (any Error).self) {
            try await data.effect(at: 5)
        }
    }

    @Test func latencyAtEmptySlotReturnsZero() async throws {
        let data = AudioUnitChainData(insertCount: 3)
        let latency = try await data.latency(at: 0)
        #expect(latency == 0)
    }

    @Test func isBypassedAtEmptySlotReturnsFalse() async throws {
        let data = AudioUnitChainData(insertCount: 3)
        let bypassed = try await data.isBypassed(at: 0)
        #expect(bypassed == false)
    }

    @Test func removeAllOnEmptyChainSucceeds() async throws {
        let data = AudioUnitChainData(insertCount: 3)
        try await data.removeAll()
        let count = await data.effectsCount
        #expect(count == 0)
    }

    @Test func removeAtEmptySlotSucceeds() async throws {
        let data = AudioUnitChainData(insertCount: 3)
        try await data.remove(index: 0)
        let effect = try await data.effect(at: 0)
        #expect(effect == nil)
    }

    // MARK: - minimumInsertCount

    @Test func minimumInsertCountIsStored() async {
        let data = AudioUnitChainData(insertCount: 5)
        let min = await data.minimumInsertCount
        #expect(min == 5)
    }

    @Test func minimumInsertCountUnchangedAfterAppend() async {
        let data = AudioUnitChainData(insertCount: 3)
        await data.appendSlot()
        let min = await data.minimumInsertCount
        #expect(min == 3)
    }

    // MARK: - appendSlot

    @Test func appendSlotIncreasesCount() async {
        let data = AudioUnitChainData(insertCount: 3)
        await data.appendSlot()
        let count = await data.insertCount
        #expect(count == 4)
    }

    @Test func appendSlotAddsEmptySlot() async throws {
        let data = AudioUnitChainData(insertCount: 3)
        await data.appendSlot()
        let effect = try await data.effect(at: 3)
        #expect(effect == nil)
    }

    // MARK: - removeLastSlot

    @Test func removeLastSlotDecreasesCount() async throws {
        let data = AudioUnitChainData(insertCount: 3)
        await data.appendSlot()
        try await data.removeLastSlot()
        let count = await data.insertCount
        #expect(count == 3)
    }

    @Test func removeLastSlotAtMinimumThrows() async {
        let data = AudioUnitChainData(insertCount: 3)
        await #expect(throws: (any Error).self) {
            try await data.removeLastSlot()
        }
    }

    @Test func removeLastSlotMultipleAppendAndRemove() async throws {
        let data = AudioUnitChainData(insertCount: 2)
        await data.appendSlot()
        await data.appendSlot()
        await data.appendSlot()
        let count = await data.insertCount
        #expect(count == 5)

        try await data.removeLastSlot()
        try await data.removeLastSlot()
        let countAfter = await data.insertCount
        #expect(countAfter == 3)
    }

    @Test func removeLastSlotStopsAtMinimum() async throws {
        let data = AudioUnitChainData(insertCount: 2)
        await data.appendSlot()
        try await data.removeLastSlot()

        // Now at minimum
        await #expect(throws: (any Error).self) {
            try await data.removeLastSlot()
        }
    }
}
