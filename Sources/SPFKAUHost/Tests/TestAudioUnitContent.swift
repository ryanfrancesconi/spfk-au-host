import AVFoundation
import SPFKAudioBase
import SPFKBase

/// This doesn't actually do any audio - it's just filling in the delegate requirements
public struct TestAudioUnitContent {
    public static let auDelayDesc = AudioComponentDescription(
        componentType: 1_635_083_896,
        componentSubType: 1_684_368_505,
        componentManufacturer: 1_634_758_764,
        componentFlags: 2,
        componentFlagsMask: 0
    )

    public static let auMatrixReverbDesc = AudioComponentDescription(
        componentType: 1_635_083_896,
        componentSubType: 1_836_213_622,
        componentManufacturer: 1_634_758_764,
        componentFlags: 2,
        componentFlagsMask: 0
    )

    public static let auFilterDesc = AudioComponentDescription(
        componentType: 1_635_083_896,
        componentSubType: 1_718_185_076,
        componentManufacturer: 1_634_758_764,
        componentFlags: 2,
        componentFlagsMask: 0
    )

    public static let auDynamicsProcessorDesc = AudioComponentDescription(
        componentType: 1_635_083_896,
        componentSubType: 1_684_237_680,
        componentManufacturer: 1_634_758_764,
        componentFlags: 2,
        componentFlagsMask: 0
    )

    public static let wavesWLMDesc = AudioComponentDescription(
        componentType: 1_635_083_896,
        componentSubType: 1_464_618_323,
        componentManufacturer: 1_802_721_110,
        componentFlags: 0,
        componentFlagsMask: 0
    )

    static var components: [AVAudioUnitComponent] {
        [
            AVAudioUnitComponent.component(matching: auDelayDesc),
            AVAudioUnitComponent.component(matching: auMatrixReverbDesc),
            AVAudioUnitComponent.component(matching: auFilterDesc),
            AVAudioUnitComponent.component(matching: auDynamicsProcessorDesc),
            AVAudioUnitComponent.component(matching: wavesWLMDesc)
        ].compactMap(\.self)
    }

    let _audioUnitManufacturerCollection: [AudioUnitManufacturerCollection]

    public init() {
        _audioUnitManufacturerCollection = AudioUnitManufacturerCollection.createGroup(from: Self.components)
    }
}

extension TestAudioUnitContent: AudioUnitChainDelegate {
    public func audioUnitChain(_ audioUnitChain: AudioUnitChain, event: AudioUnitChainEvent) async {
        Log.debug(event)
    }

    // This is where the AVAudioEngine would perform the connection
    public func connectAndAttach(_ node1: AVAudioNode, to node2: AVAudioNode, format: AVAudioFormat?) async throws {
        Log.debug(
            "\(node1.resolvedName) to \(node2.resolvedName) with \(format?.readableDescription ?? "default engine format")"
        )
    }
}

extension TestAudioUnitContent: AudioUnitAvailability {
    public var availableAudioUnitComponents: [AVAudioUnitComponent]? {
        Self.components
    }

    public var audioUnitManufacturerCollection: [AudioUnitManufacturerCollection] {
        _audioUnitManufacturerCollection
    }
}
