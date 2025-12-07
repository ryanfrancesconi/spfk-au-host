import AVFoundation
import SPFKAUHost
import SPFKBase

// This doesn't actually do any audio - it's just filling in the delegate requirements
struct DummyEngine {
    let auDelayDesc = AudioComponentDescription(
        componentType: 1_635_083_896,
        componentSubType: 1_684_368_505,
        componentManufacturer: 1_634_758_764,
        componentFlags: 2,
        componentFlagsMask: 0
    )

    let auMatrixReverbDesc = AudioComponentDescription(
        componentType: 1_635_083_896,
        componentSubType: 1_836_213_622,
        componentManufacturer: 1_634_758_764,
        componentFlags: 2,
        componentFlagsMask: 0
    )

    var components: [AVAudioUnitComponent] {
        [
            AVAudioUnitComponent.component(matching: auDelayDesc),
            AVAudioUnitComponent.component(matching: auMatrixReverbDesc),
        ].compactMap(\.self)
    }
}

extension DummyEngine: AudioUnitChainDelegate {
    func audioUnitChain(_ audioUnitChain: AudioUnitChain, event: AudioUnitChainEvent) {
        Log.debug(event)
    }

    // This is where the AVAudioEngine would perform the connection
    func connectAndAttach(_ node1: AVAudioNode, to node2: AVAudioNode, format: AVAudioFormat?) async throws {
        Log.debug(
            "\(node1.resolvedName) to \(node2.resolvedName) with \(format?.readableDescription ?? "default engine format")"
        )
    }

    var availableAudioUnitComponents: [AVAudioUnitComponent]? {
        components
    }
}
