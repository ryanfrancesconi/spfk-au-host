// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

import AVFoundation
import SPFKBase

/// Provides access to an output audio node.
public protocol NodeOutputAccess: AnyObject {
    var outputNode: AVAudioNode? { get }
}

/// Provides access to an input audio node.
public protocol NodeInputAccess: AnyObject {
    var inputNode: AVAudioNode? { get }
}

/// A node that participates in an audio engine graph, providing input/output access and bypass control.
public protocol AudioEngineNode: NodeInputAccess, NodeOutputAccess {
    var isBypassed: Bool { get set }
    func detachNodes() throws
}

extension AudioEngineNode {
    /// Default input node. Returns `nil`.
    public var inputNode: AVAudioNode? { nil }

    /// Default output node. Returns `nil`.
    public var outputNode: AVAudioNode? { nil }

    /// Default bypass state. Always returns `false`.
    public var isBypassed: Bool {
        get { false }
        set {}
    }

    /// Whether the output node has an active connection in the engine.
    public var isOutputNodeConnected: Bool {
        guard let outputNode else {
            Log.error("\(self) \(#function): engine is nil")
            return false
        }

        return outputNode.isOutputNodeConnected
    }

    /// The output format of the output node on bus 0.
    public var format: AVAudioFormat? {
        outputNode?.outputFormat(forBus: 0)
    }

    /// The `AVAudioEngine` that owns the input or output node.
    public var engine: AVAudioEngine? {
        outputNode?.engine ?? inputNode?.engine
    }

    /// The output format of the engine.
    public var engineFormat: AVAudioFormat? {
        engine?.outputFormat
    }

    /// Whether the engine is currently in manual (offline) rendering mode.
    public var isInManualRenderingMode: Bool {
        engine?.isInManualRenderingMode == true
    }

    /// Disconnects the input node from the engine graph.
    public func disconnectInput() throws {
        try inputNode?.disconnectInput()
    }

    /// Disconnects the output node from the engine graph.
    public func disconnectOutput() throws {
        try outputNode?.disconnectOutput()
    }

    /// Default behavior is to only detach the IO nodes.
    /// Can be implemented for custom handling
    public func detachNodes() throws {
        try detachIONodes()
    }

    /// Detaches the input and output nodes from the engine.
    public func detachIONodes() throws {
        guard let engine else {
            throw NSError(description: "\(self) \(#function): engine is nil")
        }

        if let inputNode {
            try inputNode.disconnectInput()
            engine.safeDetach(nodes: [inputNode])
        }

        if let outputNode, inputNode != outputNode {
            try outputNode.disconnectOutput()
            engine.safeDetach(nodes: [outputNode])
        }
    }
}
