import AudioToolbox
import AVFoundation
import Foundation
import SPFKAUHost
import Testing

@testable import SPFKAUHost

struct ComponentValidationResultTests {
    static let testDesc = AudioComponentDescription(
        componentType: 1_635_083_896,
        componentSubType: 1_684_368_505,
        componentManufacturer: 1_634_758_764,
        componentFlags: 2,
        componentFlagsMask: 0
    )

    @Test func initWithComponent() {
        guard let component = AVAudioUnitComponentManager.shared()
            .components(matching: Self.testDesc).first
        else {
            Issue.record("AUDelay not found on system")
            return
        }

        let validation = AudioUnitValidator.ValidationResult(result: .passed)
        let result = ComponentValidationResult(
            audioComponentDescription: Self.testDesc,
            component: component,
            validation: validation
        )

        #expect(result.name == component.name)
        #expect(result.manufacturerName == component.manufacturerName)
        #expect(result.typeName == component.localizedTypeName)
        #expect(result.versionString == component.versionString)
        #expect(result.isEnabled == true)
        #expect(result.component != nil)
    }

    @Test func initWithoutComponent() {
        let validation = AudioUnitValidator.ValidationResult(result: .failed)
        let result = ComponentValidationResult(
            audioComponentDescription: Self.testDesc,
            validation: validation,
            isEnabled: false,
            name: "TestAU",
            typeName: "Effect",
            manufacturerName: "TestMfg",
            versionString: "2.0"
        )

        #expect(result.name == "TestAU")
        #expect(result.typeName == "Effect")
        #expect(result.manufacturerName == "TestMfg")
        #expect(result.versionString == "2.0")
        #expect(result.isEnabled == false)
        #expect(result.component == nil)
        #expect(result.validation.result == .failed)
    }

    @Test func isFormatCompatibleWithComponent() {
        guard let component = AVAudioUnitComponentManager.shared()
            .components(matching: Self.testDesc).first
        else {
            return
        }

        let validation = AudioUnitValidator.ValidationResult(result: .passed)
        let result = ComponentValidationResult(
            audioComponentDescription: Self.testDesc,
            component: component,
            validation: validation
        )

        // AUDelay is an effect that supports stereo, so should be format compatible
        #expect(result.isFormatCompatible == true)
    }

    @Test func isFormatCompatibleWithoutComponent() {
        let validation = AudioUnitValidator.ValidationResult(result: .passed)
        let result = ComponentValidationResult(
            audioComponentDescription: Self.testDesc,
            validation: validation,
            name: "Test",
            typeName: "Effect",
            manufacturerName: "Apple",
            versionString: "1.0"
        )

        // Without a component, supportsStereo returns false
        #expect(result.isFormatCompatible == false)
    }

    @Test func supportsMonoWithoutComponent() {
        let validation = AudioUnitValidator.ValidationResult(result: .passed)
        let result = ComponentValidationResult(
            audioComponentDescription: Self.testDesc,
            validation: validation,
            name: "Test",
            typeName: "Effect",
            manufacturerName: "Apple",
            versionString: "1.0"
        )

        #expect(result.supportsMono == false)
    }

    @Test func supportsStereoWithoutComponent() {
        let validation = AudioUnitValidator.ValidationResult(result: .passed)
        let result = ComponentValidationResult(
            audioComponentDescription: Self.testDesc,
            validation: validation,
            name: "Test",
            typeName: "Effect",
            manufacturerName: "Apple",
            versionString: "1.0"
        )

        #expect(result.supportsStereo == false)
    }

    @Test func descriptionWithComponent() {
        guard let component = AVAudioUnitComponentManager.shared()
            .components(matching: Self.testDesc).first
        else {
            return
        }

        let validation = AudioUnitValidator.ValidationResult(result: .passed)
        let result = ComponentValidationResult(
            audioComponentDescription: Self.testDesc,
            component: component,
            validation: validation
        )

        let desc = result.description
        #expect(desc.contains(component.manufacturerName))
        #expect(desc.contains(component.name))
    }

    @Test func descriptionWithoutComponent() {
        let validation = AudioUnitValidator.ValidationResult(result: .passed)
        let result = ComponentValidationResult(
            audioComponentDescription: Self.testDesc,
            validation: validation,
            name: "Test",
            typeName: "Effect",
            manufacturerName: "Apple",
            versionString: "1.0"
        )

        let desc = result.description
        #expect(!desc.isEmpty)
    }

    @Test func isEnabledMutability() {
        let validation = AudioUnitValidator.ValidationResult(result: .passed)
        var result = ComponentValidationResult(
            audioComponentDescription: Self.testDesc,
            validation: validation,
            name: "Test",
            typeName: "Effect",
            manufacturerName: "Apple",
            versionString: "1.0"
        )

        #expect(result.isEnabled == true)
        result.isEnabled = false
        #expect(result.isEnabled == false)
    }
}
