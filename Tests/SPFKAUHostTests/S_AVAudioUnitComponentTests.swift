import AudioToolbox
import AVFoundation
import Foundation
import Testing

@testable import SPFKAUHost

struct S_AVAudioUnitComponentTests {
    static let testDesc = AudioComponentDescription(
        componentType: 1_635_083_896,
        componentSubType: 1_684_368_505,
        componentManufacturer: 1_634_758_764,
        componentFlags: 2,
        componentFlagsMask: 0
    )

    @Test func equalitySameDescription() {
        guard let component = AVAudioUnitComponentManager.shared()
            .components(matching: Self.testDesc).first
        else {
            return
        }

        let a = S_AVAudioUnitComponent(avAudioUnitComponent: component)
        let b = S_AVAudioUnitComponent(avAudioUnitComponent: component)

        #expect(a == b)
    }

    @Test func inequalityDifferentDescription() {
        let delayDesc = Self.testDesc
        let reverbDesc = AudioComponentDescription(
            componentType: 1_635_083_896,
            componentSubType: 1_836_213_622,
            componentManufacturer: 1_634_758_764,
            componentFlags: 2,
            componentFlagsMask: 0
        )

        guard let delayComponent = AVAudioUnitComponentManager.shared()
            .components(matching: delayDesc).first,
            let reverbComponent = AVAudioUnitComponentManager.shared()
            .components(matching: reverbDesc).first
        else {
            return
        }

        let a = S_AVAudioUnitComponent(avAudioUnitComponent: delayComponent)
        let b = S_AVAudioUnitComponent(avAudioUnitComponent: reverbComponent)

        #expect(a != b)
    }
}
