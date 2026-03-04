import AudioToolbox
import Foundation
import Testing

@testable import SPFKAUHost

// MARK: - HostMusicalContext

struct HostMusicalContextTests {
    @Test func defaultValues() {
        let context = HostMusicalContext()
        #expect(context.currentTempo == 120)
        #expect(context.timeSignatureNumerator == 4)
        #expect(context.timeSignatureDenominator == 4)
        #expect(context.currentBeatPosition == 0)
        #expect(context.currentMeasureDownbeatPosition == 0)
        #expect(context.sampleOffsetToNextBeat == 0)
    }

    @Test func mutability() {
        var context = HostMusicalContext()
        context.currentTempo = 140
        context.timeSignatureNumerator = 3
        context.timeSignatureDenominator = 8
        context.currentBeatPosition = 5.5
        context.currentMeasureDownbeatPosition = 4.0
        context.sampleOffsetToNextBeat = 256

        #expect(context.currentTempo == 140)
        #expect(context.timeSignatureNumerator == 3)
        #expect(context.timeSignatureDenominator == 8)
        #expect(context.currentBeatPosition == 5.5)
        #expect(context.currentMeasureDownbeatPosition == 4.0)
        #expect(context.sampleOffsetToNextBeat == 256)
    }
}

// MARK: - HostTransportState

struct HostTransportStateTests {
    @Test func defaultValues() {
        let state = HostTransportState()
        #expect(state.currentSamplePosition == 0)
        #expect(state.cycleStartBeatPosition == 0)
        #expect(state.cycleEndBeatPosition == 0)
    }

    @Test func mutability() {
        var state = HostTransportState()
        state.currentSamplePosition = 44100
        state.cycleStartBeatPosition = 1.0
        state.cycleEndBeatPosition = 5.0

        #expect(state.currentSamplePosition == 44100)
        #expect(state.cycleStartBeatPosition == 1.0)
        #expect(state.cycleEndBeatPosition == 5.0)
    }
}

// MARK: - HostAUState

struct HostAUStateTests {
    @Test func defaultValues() {
        let state = HostAUState()
        #expect(state.isEnabled == true)
        #expect(state.musicalContext.currentTempo == 120)
        #expect(state.transportState.currentSamplePosition == 0)
    }

    @Test func musicalContextBlockReturnsTrueAndSetsValues() {
        var state = HostAUState()
        state.musicalContext.currentTempo = 100
        state.musicalContext.timeSignatureNumerator = 6
        state.musicalContext.timeSignatureDenominator = 8
        state.musicalContext.currentBeatPosition = 3.5
        state.musicalContext.sampleOffsetToNextBeat = 512
        state.musicalContext.currentMeasureDownbeatPosition = 2.0

        let block = state.musicalContextBlock

        var tempo: Double = 0
        var numerator: Double = 0
        var denominator: Int = 0
        var beatPos: Double = 0
        var sampleOffset: Int = 0
        var downbeatPos: Double = 0

        let result = block(&tempo, &numerator, &denominator, &beatPos, &sampleOffset, &downbeatPos)

        #expect(result == true)
        #expect(tempo == 100)
        #expect(numerator == 6)
        #expect(denominator == 8)
        #expect(beatPos == 3.5)
        #expect(sampleOffset == 512)
        #expect(downbeatPos == 2.0)
    }

    @Test func musicalContextBlockHandlesNilPointers() {
        let state = HostAUState()
        let block = state.musicalContextBlock

        let result = block(nil, nil, nil, nil, nil, nil)
        #expect(result == true)
    }

    @Test func transportStateBlockReturnsTrueAndSetsValues() {
        var state = HostAUState()
        state.transportState.currentSamplePosition = 88200
        state.transportState.cycleStartBeatPosition = 1.0
        state.transportState.cycleEndBeatPosition = 9.0

        let block = state.transportStateBlock

        var flags = AUHostTransportStateFlags()
        var samplePos: Double = 0
        var cycleStart: Double = 0
        var cycleEnd: Double = 0

        let result = block(&flags, &samplePos, &cycleStart, &cycleEnd)

        #expect(result == true)
        #expect(samplePos == 88200)
        #expect(cycleStart == 1.0)
        #expect(cycleEnd == 9.0)
    }

    @Test func transportStateBlockHandlesNilPointers() {
        let state = HostAUState()
        let block = state.transportStateBlock

        let result = block(nil, nil, nil, nil)
        #expect(result == true)
    }

    @Test func isEnabledMutability() {
        var state = HostAUState()
        #expect(state.isEnabled == true)
        state.isEnabled = false
        #expect(state.isEnabled == false)
    }
}
