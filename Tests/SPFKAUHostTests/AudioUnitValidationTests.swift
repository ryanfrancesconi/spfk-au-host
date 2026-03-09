// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

import AudioToolbox
import AVFoundation
import Foundation
import SPFKAudioBase
import SPFKBase
import SPFKTesting
import Testing

@testable import SPFKAUHost

// MARK: - shouldValidate

struct ShouldValidateTests {
    @Test func appleManufacturerIsSkipped() {
        let desc = AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: 0,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )

        #expect(AudioUnitCacheManager.shouldValidate(audioComponentDescription: desc) == false)
    }

    @Test func spongeforkManufacturerIsSkipped() {
        let desc = AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: 0,
            componentManufacturer: kAudioUnitManufacturer_Spongefork,
            componentFlags: 0,
            componentFlagsMask: 0
        )

        #expect(AudioUnitCacheManager.shouldValidate(audioComponentDescription: desc) == false)
    }

    @Test func thirdPartyManufacturerIsValidated() {
        let desc = AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: 0,
            componentManufacturer: 0x12345678,
            componentFlags: 0,
            componentFlagsMask: 0
        )

        #expect(AudioUnitCacheManager.shouldValidate(audioComponentDescription: desc) == true)
    }
}

// MARK: - Validate with TaskGroup

@Suite(.serialized, .tags(.realtime))
final class ValidateTaskGroupTests: BinTestCase, @unchecked Sendable {
    lazy var manager = AudioUnitCacheManager(cachesDirectory: bin)

    var receivedEvents: [AudioUnitCacheEvent] = []

    override init() async {
        await super.init()
    }

    func tearDown() async throws {
        await manager.dispose()
    }

    @Test func validateReturnsResultsForAllComponents() async throws {
        await manager.update(delegate: self)

        // Use a small set of known Apple components
        let components = Array(AudioUnitCacheManager.compatibleComponents.prefix(3))
        guard components.count == 3 else {
            Issue.record("Need at least 3 compatible components on this system")
            return
        }

        let results = try await manager.validate(components: components)

        #expect(results.count == 3)

        // Apple components should all pass (they're skipped by shouldValidate)
        for result in results {
            #expect(result.validation.result == .passed)
        }

        try await tearDown()
    }

    @Test func validateResultsSortedByManufacturer() async throws {
        await manager.update(delegate: self)

        let components = Array(AudioUnitCacheManager.compatibleComponents.prefix(5))
        guard components.count >= 2 else {
            Issue.record("Need at least 2 compatible components on this system")
            return
        }

        let results = try await manager.validate(components: components)

        // Verify sorted by manufacturerName
        for i in 0 ..< results.count - 1 {
            #expect(results[i].manufacturerName <= results[i + 1].manufacturerName)
        }

        try await tearDown()
    }

    @Test func validateSendsProgressEvents() async throws {
        await manager.update(delegate: self)

        let components = Array(AudioUnitCacheManager.compatibleComponents.prefix(3))
        guard !components.isEmpty else {
            Issue.record("Need at least 1 compatible component")
            return
        }

        let expectedCount = components.count
        _ = try await manager.validate(components: components)

        // Should have received .validating events
        let validatingEvents = receivedEvents.filter {
            if case .validating = $0 { return true }
            return false
        }

        #expect(validatingEvents.count == expectedCount)

        try await tearDown()
    }

    @Test func validateClearsScantaskWhenDone() async throws {
        await manager.update(delegate: self)

        let components = Array(AudioUnitCacheManager.compatibleComponents.prefix(2))
        guard !components.isEmpty else { return }

        _ = try await manager.validate(components: components)

        let isScanning = await manager.isScanning
        #expect(isScanning == false)

        try await tearDown()
    }

    @Test func validateEmptyComponentsReturnsEmpty() async throws {
        await manager.update(delegate: self)

        let results = try await manager.validate(components: [])

        #expect(results.isEmpty)

        try await tearDown()
    }
}

extension ValidateTaskGroupTests: AudioUnitCacheManagerDelegate {
    func handleAudioUnitCacheManager(event: AudioUnitCacheEvent) async {
        receivedEvents.append(event)
    }
}

// MARK: - AudioUnitValidator

struct AudioUnitValidatorTests {
    static let auDelayDesc = AudioComponentDescription(
        componentType: 1_635_083_896,
        componentSubType: 1_684_368_505,
        componentManufacturer: 1_634_758_764,
        componentFlags: 2,
        componentFlagsMask: 0
    )

    @Test func validateAppleComponentPasses() async throws {
        guard let component = AVAudioUnitComponentManager.shared()
            .components(matching: Self.auDelayDesc).first
        else {
            Issue.record("AUDelay not found on system")
            return
        }

        let result = await AudioUnitValidator.validate(component: component)

        #expect(result.result == .passed)
    }

    @Test func cachedSystemValidationResultForAppleComponent() async throws {
        guard let component = AVAudioUnitComponentManager.shared()
            .components(matching: Self.auDelayDesc).first
        else {
            Issue.record("AUDelay not found on system")
            return
        }

        // Apple components should have a cached system result
        let cachedResult = AudioUnitValidator.cachedSystemValidationResult(for: component)

        // May or may not be cached, but if present it should be .passed
        if let cachedResult {
            #expect(cachedResult == .passed)
        }
    }

    @Test func validateLegacyAppleComponentPasses() async throws {
        guard let component = AVAudioUnitComponentManager.shared()
            .components(matching: Self.auDelayDesc).first
        else {
            Issue.record("AUDelay not found on system")
            return
        }

        let result = await AudioUnitValidator.validateLegacy(component: component)

        #expect(result.result == .passed)
    }

    @Test func validationResultInit() {
        let result = AudioUnitValidator.ValidationResult(result: .passed)
        #expect(result.result == .passed)
        #expect(result.output == nil)
    }

    @Test func validationResultWithOutput() {
        let result = AudioUnitValidator.ValidationResult(result: .failed, output: "error details")
        #expect(result.result == .failed)
        #expect(result.output == "error details")
    }

    #if os(macOS)
        @Test func auvalToolExists() {
            // On macOS, at least one of auval or auvaltool should exist
            let tool = AudioUnitValidator.auval
            #expect(tool != nil)
        }
    #endif
}

// MARK: - AudioUnitCacheObservation

struct AudioUnitCacheObservationTests {
    @Test func startSetsIsObserving() {
        let observation = AudioUnitCacheObservation()
        #expect(observation.isObserving == false)

        observation.start()
        #expect(observation.isObserving == true)

        observation.stop()
    }

    @Test func stopClearsIsObserving() {
        let observation = AudioUnitCacheObservation()

        observation.start()
        #expect(observation.isObserving == true)

        observation.stop()
        #expect(observation.isObserving == false)
    }

    @Test func doubleStartIsIdempotent() {
        let observation = AudioUnitCacheObservation()

        observation.start()
        observation.start()
        #expect(observation.isObserving == true)

        observation.stop()
        #expect(observation.isObserving == false)
    }

    @Test func doubleStopIsIdempotent() {
        let observation = AudioUnitCacheObservation()

        observation.start()
        observation.stop()
        observation.stop()
        #expect(observation.isObserving == false)
    }

    @Test func stopBeforeStartIsNoop() {
        let observation = AudioUnitCacheObservation()

        observation.stop()
        #expect(observation.isObserving == false)
    }
}
