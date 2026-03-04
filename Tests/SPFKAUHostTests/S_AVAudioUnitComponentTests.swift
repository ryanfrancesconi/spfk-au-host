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

    @Test func initFromAVAudioUnitComponent() {
        guard let component = AVAudioUnitComponentManager.shared()
            .components(matching: Self.testDesc).first
        else {
            Issue.record("AUDelay not found on system")
            return
        }

        let sendable = S_AVAudioUnitComponent(avAudioUnitCompoment: component)

        #expect(sendable.name == component.name)
        #expect(sendable.typeName == component.typeName)
        #expect(sendable.localizedTypeName == component.localizedTypeName)
        #expect(sendable.manufacturerName == component.manufacturerName)
        #expect(sendable.version == component.version)
        #expect(sendable.versionString == component.versionString)
        #expect(sendable.isSandboxSafe == component.isSandboxSafe)
        #expect(sendable.hasMIDIInput == component.hasMIDIInput)
        #expect(sendable.hasMIDIOutput == component.hasMIDIOutput)
        #expect(sendable.hasCustomView == component.hasCustomView)
    }

    @Test func equalitySameDescription() {
        guard let component = AVAudioUnitComponentManager.shared()
            .components(matching: Self.testDesc).first
        else {
            return
        }

        let a = S_AVAudioUnitComponent(avAudioUnitCompoment: component)
        let b = S_AVAudioUnitComponent(avAudioUnitCompoment: component)

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

        let a = S_AVAudioUnitComponent(avAudioUnitCompoment: delayComponent)
        let b = S_AVAudioUnitComponent(avAudioUnitCompoment: reverbComponent)

        #expect(a != b)
    }

    @Test func audioComponentDescriptionPreserved() {
        guard let component = AVAudioUnitComponentManager.shared()
            .components(matching: Self.testDesc).first
        else {
            return
        }

        let sendable = S_AVAudioUnitComponent(avAudioUnitCompoment: component)

        #expect(sendable.audioComponentDescription.componentType == Self.testDesc.componentType)
        #expect(sendable.audioComponentDescription.componentSubType == Self.testDesc.componentSubType)
        #expect(sendable.audioComponentDescription.componentManufacturer == Self.testDesc.componentManufacturer)
    }
}

// MARK: - SystemComponentsResponse

struct SystemComponentsResponseTests {
    @Test func defaultInit() {
        let response = SystemComponentsResponse()
        #expect(response.results.isEmpty)
    }

    @Test func initWithResults() {
        let validation = AudioUnitValidator.ValidationResult(result: .passed)
        let result = ComponentValidationResult(
            audioComponentDescription: S_AVAudioUnitComponentTests.testDesc,
            validation: validation,
            name: "Test",
            typeName: "Effect",
            manufacturerName: "Apple",
            versionString: "1.0",
            icon: nil
        )

        let response = SystemComponentsResponse(results: [result])
        #expect(response.results.count == 1)
        #expect(response.results.first?.name == "Test")
    }
}
