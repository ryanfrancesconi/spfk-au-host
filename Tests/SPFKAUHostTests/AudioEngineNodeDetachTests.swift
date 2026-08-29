// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

import AVFoundation
import Foundation
import SPFKAudioBase
import SPFKAUHost
import SPFKBase
import Testing

@Suite(.serialized)
struct AudioEngineNodeDetachTests {
    private final class DetachableNode: AudioEngineNode, @unchecked Sendable {
        let mixer = AVAudioMixerNode()

        var inputNode: AVAudioNode? { mixer }
        var outputNode: AVAudioNode? { mixer }
    }

    /// A rebuild detaches the node before its owner gets to, so teardown routinely runs against a
    /// node with no engine. Reporting that as a failure is what drove every caller to `try?`, which
    /// then swallowed the real failures too.
    @Test func detachingANodeWithNoEngineSucceeds() throws {
        let node = DetachableNode()

        #expect(node.mixer.engine == nil)

        try node.detachIONodes()
        try node.detachNodes()
    }

    /// And it stays a no-op after a real detach, so a second teardown pass is harmless.
    @Test func detachingTwiceSucceeds() throws {
        let engine = AVAudioEngine()
        let node = DetachableNode()

        engine.attach(node.mixer)
        #expect(node.mixer.engine != nil)

        try node.detachIONodes()
        #expect(node.mixer.engine == nil)

        try node.detachIONodes()
    }
}
