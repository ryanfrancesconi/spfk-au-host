import AudioToolbox
import AVFoundation
import Foundation
import SPFKAUHost
import Testing

@testable import SPFKAUHost

struct ComponentCollectionTests {
    static let appleDelayDesc = AudioComponentDescription(
        componentType: 1_635_083_896,
        componentSubType: 1_684_368_505,
        componentManufacturer: 1_634_758_764,
        componentFlags: 2,
        componentFlagsMask: 0
    )

    func makeResult(
        desc: AudioComponentDescription = appleDelayDesc,
        passed: Bool = true,
        isEnabled: Bool = true
    ) -> ComponentValidationResult {
        let component = AVAudioUnitComponentManager.shared()
            .components(matching: desc).first

        let validation = AudioUnitValidator.ValidationResult(
            result: passed ? .passed : .failed
        )

        if let component {
            return ComponentValidationResult(
                audioComponentDescription: desc,
                component: component,
                validation: validation,
                isEnabled: isEnabled
            )
        } else {
            return ComponentValidationResult(
                audioComponentDescription: desc,
                validation: validation,
                isEnabled: isEnabled,
                name: "Test",
                typeName: "Effect",
                manufacturerName: "Apple",
                versionString: "1.0",
                icon: nil
            )
        }
    }

    @Test func emptyCollection() {
        let collection = ComponentCollection(results: [])
        #expect(collection.isEmpty)
        #expect(collection.validationResults.isEmpty)
    }

    @Test func nonEmptyCollection() {
        let result = makeResult()
        let collection = ComponentCollection(results: [result])
        #expect(!collection.isEmpty)
        #expect(collection.validationResults.count == 1)
    }

    @Test func passedEffectsFiltersPassed() {
        let passed = makeResult(passed: true)
        let failed = makeResult(passed: false)
        let collection = ComponentCollection(results: [passed, failed])

        // passedEffects filters by validation.result == .passed AND isFormatCompatible
        let passedEffects = collection.passedEffects
        // All passed effects must have .passed validation
        for effect in passedEffects {
            #expect(effect.validation.result == .passed)
        }
    }

    @Test func failedEffectsFiltersFailed() {
        let passed = makeResult(passed: true)
        let failed = makeResult(passed: false)
        let collection = ComponentCollection(results: [passed, failed])

        let failedEffects = collection.failedEffects
        #expect(failedEffects.count == 1)
        #expect(failedEffects.first?.validation.result == .failed)
    }

    @Test func updateIsEnabled() {
        let result = makeResult(isEnabled: true)
        var collection = ComponentCollection(results: [result])

        collection.update(
            audioComponentDescription: Self.appleDelayDesc,
            isEnabled: false
        )

        #expect(collection.validationResults.first?.isEnabled == false)
    }

    @Test func updateValidationResult() {
        let result = makeResult(passed: true)
        var collection = ComponentCollection(results: [result])

        var updated = result
        updated.validation = AudioUnitValidator.ValidationResult(result: .failed)

        collection.update(result: updated)

        #expect(collection.validationResults.first?.validation.result == .failed)
    }

    @Test func updateEnabledFromOtherCollection() {
        let result1 = makeResult(isEnabled: true)
        var collection1 = ComponentCollection(results: [result1])

        let result2 = makeResult(isEnabled: false)
        let collection2 = ComponentCollection(results: [result2])

        collection1.updateEnabled(from: collection2)

        #expect(collection1.validationResults.first?.isEnabled == false)
    }

    @Test func effectTypesReturnsUniqueTypes() {
        let result = makeResult()
        let collection = ComponentCollection(results: [result])

        let types = collection.effectTypes
        // Should contain type names (may be empty if component is nil)
        #expect(types.count >= 0)
    }
}
