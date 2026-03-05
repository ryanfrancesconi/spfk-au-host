// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

import AVFoundation
import SPFKBase

/// Protocol for connecting and attaching audio nodes within an audio engine.
public protocol AudioEngineConnection: Sendable {
    func connectAndAttach(_ node1: AVAudioNode, to node2: AVAudioNode, format: AVAudioFormat?) async throws
}

extension AudioEngineConnection {
    /// Connects and attaches two audio nodes using the system format.
    public func connectAndAttach(_ node1: AVAudioNode, to node2: AVAudioNode) async throws {
        try await connectAndAttach(node1, to: node2, format: nil) // use systemFormat
    }

    /// Connects and attaches two `AudioEngineNode` instances using their respective output and input nodes.
    public func connectAndAttach(
        _ engineNode: any AudioEngineNode,
        to otherEngineNode: any AudioEngineNode,
        format: AVAudioFormat? = nil
    ) async throws {
        guard let sourceNode = engineNode.outputNode else {
            throw NSError(description: "engineNode.outputNode must be valid")
        }

        guard let destinationNode = otherEngineNode.inputNode else {
            throw NSError(description: "otherEngineNode.inputNode must be valid")
        }

        try await connectAndAttach(sourceNode, to: destinationNode, format: format)
    }
}
