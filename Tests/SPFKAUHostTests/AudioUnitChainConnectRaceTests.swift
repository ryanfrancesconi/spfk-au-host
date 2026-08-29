// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

import AVFoundation
import Foundation
import SPFKAudioBase
import SPFKAUHost
import SPFKBase
import SPFKTesting
import Testing

/// Records what was connected, and runs a hook inside the next connection — the suspension a
/// concurrent `updateIO`/`dispose` reenters the actor through.
final class RecordingChainDelegate: AudioUnitChainDelegate, @unchecked Sendable {
    private let content = AudioUnitTestContent()

    /// Runs once, inside the next `connectAndAttach`, before the connection is recorded.
    var interposeOnNextConnect: (() async throws -> Void)?

    var connections: [(AVAudioNode, AVAudioNode)] = []

    func audioUnitChain(_ audioUnitChain: AudioUnitChain, event: AudioUnitChainEvent) async {}

    func connectAndAttach(_ node1: AVAudioNode, to node2: AVAudioNode, format: AVAudioFormat?) async throws {
        if let hook = interposeOnNextConnect {
            interposeOnNextConnect = nil
            try await hook()
        }

        connections.append((node1, node2))
    }

    var availableAudioUnitComponents: [AVAudioUnitComponent]? {
        content.availableAudioUnitComponents
    }

    var audioUnitManufacturerCollection: [AudioUnitManufacturerCollection] {
        content.audioUnitManufacturerCollection
    }
}

@Suite(.serialized)
struct AudioUnitChainConnectRaceTests {
    /// `connect()` binds `input` and `output` once and then makes a chain of connections across
    /// suspensions. `AudioUnitChain` is an actor, so `dispose()` reenters it in that window and
    /// releases both — and the connections that follow would wire the chain to nodes it no longer
    /// holds, reporting success.
    @Test func connectReportsWhenDisposeReleasesTheIOWhileItIsSuspended() async throws {
        let delegate = RecordingChainDelegate()
        let chain = AudioUnitChain(delegate: delegate)

        nonisolated(unsafe) let input = AVAudioPlayerNode()
        nonisolated(unsafe) let output = AVAudioMixerNode()
        try await chain.updateIO(input: input, output: output)

        delegate.connections.removeAll()

        delegate.interposeOnNextConnect = {
            try await chain.dispose()
        }

        await #expect(throws: (any Error).self) {
            try await chain.connect()
        }
    }

    /// The inverse: `updateIO` replaces both nodes rather than clearing them, so the remaining
    /// connections have somewhere wrong to land rather than nowhere. The tail of the chain must not
    /// reach the output the chain has already replaced.
    @Test func connectDoesNotWireTheChainTailToAReplacedOutput() async throws {
        let delegate = RecordingChainDelegate()
        let chain = AudioUnitChain(delegate: delegate)

        nonisolated(unsafe) let staleInput = AVAudioPlayerNode()
        nonisolated(unsafe) let staleOutput = AVAudioMixerNode()
        try await chain.updateIO(input: staleInput, output: staleOutput)

        try await chain.insertAudioUnit(componentDescription: AudioUnitTestContent.auDelayDesc, at: 0)
        try await chain.insertAudioUnit(componentDescription: AudioUnitTestContent.auMatrixReverbDesc, at: 1)

        nonisolated(unsafe) let currentInput = AVAudioPlayerNode()
        nonisolated(unsafe) let currentOutput = AVAudioMixerNode()

        delegate.connections.removeAll()

        delegate.interposeOnNextConnect = {
            try await chain.updateIO(input: currentInput, output: currentOutput)
        }

        await #expect(throws: (any Error).self) {
            try await chain.connect()
        }

        let reachedStaleOutput = delegate.connections.contains { $0.1 === staleOutput }

        #expect(
            !reachedStaleOutput,
            "the chain tail was wired to the output that had already been replaced"
        )
    }
}
