import AVFoundation
import SPFKAUHost
import SPFKBase

/// This doesn't actually do any audio - it's just filling in the delegate requirements
struct DummyEngine {
    static let auDelayDesc = AudioComponentDescription(
        componentType: 1_635_083_896,
        componentSubType: 1_684_368_505,
        componentManufacturer: 1_634_758_764,
        componentFlags: 2,
        componentFlagsMask: 0
    )

    static let auMatrixReverbDesc = AudioComponentDescription(
        componentType: 1_635_083_896,
        componentSubType: 1_836_213_622,
        componentManufacturer: 1_634_758_764,
        componentFlags: 2,
        componentFlagsMask: 0
    )

    static let auFilterDesc = AudioComponentDescription(
        componentType: 1_635_083_896,
        componentSubType: 1_718_185_076,
        componentManufacturer: 1_634_758_764,
        componentFlags: 2,
        componentFlagsMask: 0
    )

    static var components: [AVAudioUnitComponent] {
        [
            AVAudioUnitComponent.component(matching: auDelayDesc),
            AVAudioUnitComponent.component(matching: auMatrixReverbDesc),
            AVAudioUnitComponent.component(matching: auFilterDesc),
        ].compactMap(\.self)
    }

    let _audioUnitManufactererCollection: [AudioUnitManufacturerCollection]

    init() {
        _audioUnitManufactererCollection = AudioUnitManufacturerCollection.createGroup(from: Self.components)
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
}

extension DummyEngine: AudioUnitAvailability {
    var availableAudioUnitComponents: [AVAudioUnitComponent]? {
        Self.components
    }

    var audioUnitManufactererCollection: [AudioUnitManufacturerCollection] {
        _audioUnitManufactererCollection
    }
}
