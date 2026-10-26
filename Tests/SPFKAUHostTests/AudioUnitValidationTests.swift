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
            componentManufacturer: 0x1234_5678,
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

    func tearDown() async {
        await manager.dispose()
    }

    @Test func validateReturnsResultsForAllComponents() async throws {
        defer { await tearDown() }

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
    }

    @Test func validateResultsSortedByManufacturer() async throws {
        defer { await tearDown() }

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
    }

    @Test func validateSendsProgressEvents() async throws {
        defer { await tearDown() }

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
    }

    @Test func validateClearsScantaskWhenDone() async throws {
        defer { await tearDown() }

        await manager.update(delegate: self)

        let components = Array(AudioUnitCacheManager.compatibleComponents.prefix(2))
        guard !components.isEmpty else { return }

        _ = try await manager.validate(components: components)

        let isScanning = await manager.isScanning
        #expect(isScanning == false)
    }

    @Test func validateEmptyComponentsReturnsEmpty() async throws {
        defer { await tearDown() }

        await manager.update(delegate: self)

        let results = try await manager.validate(components: [])

        #expect(results.isEmpty)
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

    /// Forced, so the system really runs a validation for the cancellation to interrupt.
    @Test(.tags(.audioUnit)) func cancelledSystemValidationReturnsPromptly() async throws {
        let component = try #require(
            AVAudioUnitComponentManager.shared().components(matching: Self.auDelayDesc).first
        )

        let start = ContinuousClock.now
        let task = Task { await AudioUnitValidator.validateWithResults(component: component, force: true) }
        task.cancel()

        let result = await task.value
        #expect(result.result == .unknown)
        #expect(ContinuousClock.now - start < .seconds(5))
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

#if os(macOS)
    // MARK: - validateExternal

    struct AudioUnitValidatorExternalTests {
        private func auDelay() throws -> AVAudioUnitComponent {
            try #require(AVAudioUnitComponentManager.shared().components(matching: AudioUnitValidatorTests.auDelayDesc).first)
        }

        /// A stand-in for `auval` that ignores its arguments and runs `body`.
        private func fakeAuval(_ body: String) throws -> URL {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("fake-auval-\(UUID().uuidString)")
            try "#!/bin/sh\n\(body)\n".write(to: url, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
            return url
        }

        // MARK: Routing

        private func route(
            forceExternal: Bool = false,
            executable: URL? = URL(fileURLWithPath: "/usr/bin/true"),
            system: AudioComponentValidationResult,
            external: AudioComponentValidationResult
        ) async throws -> (result: AudioComponentValidationResult, calls: [String]) {
            let calls = Locked<[String]>([])
            let result = await AudioUnitValidator.validate(
                component: try auDelay(),
                forceExternal: forceExternal,
                executable: executable,
                system: { _ in
                    calls.mutate { $0.append("system") }
                    return AudioUnitValidator.ValidationResult(result: system)
                },
                external: { _, _ in
                    calls.mutate { $0.append("external") }
                    return AudioUnitValidator.ValidationResult(result: external)
                }
            )
            return (result.result, calls.value)
        }

        @Test func systemTimeoutIsDecidedByExternal() async throws {
            let routed = try await route(system: .timedOut, external: .passed)
            #expect(routed.result == .passed)
            #expect(routed.calls == ["system", "external"])
        }

        @Test func systemFailureIsDecidedByExternal() async throws {
            let routed = try await route(system: .failed, external: .passed)
            #expect(routed.result == .passed)
            #expect(routed.calls == ["system", "external"])
        }

        @Test func systemPassSkipsExternal() async throws {
            let routed = try await route(system: .passed, external: .failed)
            #expect(routed.result == .passed)
            #expect(routed.calls == ["system"])
        }

        @Test func forceExternalSkipsSystem() async throws {
            let routed = try await route(forceExternal: true, system: .passed, external: .failed)
            #expect(routed.result == .failed)
            #expect(routed.calls == ["external"])
        }

        @Test func noExecutableKeepsSystemResult() async throws {
            let routed = try await route(executable: nil, system: .failed, external: .passed)
            #expect(routed.result == .failed)
            #expect(routed.calls == ["system"])
        }

        @Test func cancelledSystemNonPassSkipsExternal() async throws {
            let task = Task {
                withUnsafeCurrentTask { $0?.cancel() }
                return try await route(system: .unknown, external: .passed)
            }
            let routed = try await task.value
            #expect(routed.result == .unknown)
            #expect(routed.calls == ["system"])
        }

        // MARK: Reason

        @Test func reasonIsTheErrorLineWithoutItsPrefix() {
            let lines = [
                "VERIFYING DEFAULT SCOPE FORMATS:",
                "WARNING: Unit does not declare a channel layout",
                "  ERROR: Parameter did not retain set value when Initialized",
                "ERROR: a second error",
            ]
            #expect(AudioUnitValidator.reason(fromOutput: lines) == "Parameter did not retain set value when Initialized")
        }

        @Test func fatalErrorIsKeptWhole() {
            let lines = ["FATAL ERROR: OpenAComponent: result: -1,0xFFFFFFFF"]
            #expect(AudioUnitValidator.reason(fromOutput: lines) == "FATAL ERROR: OpenAComponent: result: -1,0xFFFFFFFF")
        }

        @Test func warningsAreNotReasons() {
            #expect(AudioUnitValidator.reason(fromOutput: ["WARNING: something", "AU VALIDATION SUCCEEDED."]) == nil)
        }

        @Test func externalFailureCarriesItsReason() async throws {
            let fake = try fakeAuval("echo 'ERROR: Cannot get Component Name strings'")
            defer { try? FileManager.default.removeItem(at: fake) }

            let result = await AudioUnitValidator.validateExternal(component: try auDelay(), executable: fake)
            #expect(result.result == .failed)
            #expect(result.reason == "Cannot get Component Name strings")
        }

        @Test func externalTimeoutReasonNamesTheTimeout() async throws {
            let fake = try fakeAuval("sleep 20")
            defer { try? FileManager.default.removeItem(at: fake) }

            let result = await AudioUnitValidator.validateExternal(component: try auDelay(), executable: fake, timeout: .seconds(1))
            #expect(result.reason == "No response within 1 seconds")
        }

        // MARK: auval

        @Test func parseReadsEachVerdict() {
            #expect(AudioUnitValidator.parse(result: "...\nAU VALIDATION SUCCEEDED.\n") == .passed)
            #expect(AudioUnitValidator.parse(result: "FATAL ERROR: OpenAComponent: result: -1") == .unauthorizedError_Open)
            #expect(AudioUnitValidator.parse(result: "FATAL ERROR: Initialize: result: -1") == .unauthorizedError_Init)
            #expect(AudioUnitValidator.parse(result: "ERROR: Cannot get Component's Name strings") == .failed)
        }

        @Test func verdictOnStderrIsRead() async throws {
            let fake = try fakeAuval("echo 'AU VALIDATION SUCCEEDED.' >&2")
            defer { try? FileManager.default.removeItem(at: fake) }

            let result = await AudioUnitValidator.validateExternal(component: try auDelay(), executable: fake)
            #expect(result.result == .passed)
        }

        @Test func hungValidatorTimesOut() async throws {
            let fake = try fakeAuval("sleep 20")
            defer { try? FileManager.default.removeItem(at: fake) }

            let start = ContinuousClock.now
            let result = await AudioUnitValidator.validateExternal(component: try auDelay(), executable: fake, timeout: .milliseconds(300))
            #expect(result.result == .timedOut)
            #expect(ContinuousClock.now - start < .seconds(10))
        }

        /// Needs the component registry, which a sandboxed run cannot see.
        @Test(.tags(.audioUnit)) func realAuvalPassesAppleComponent() async throws {
            let result = await AudioUnitValidator.validateExternal(component: try auDelay())
            #expect(result.result == .passed, "\(result.output ?? "")")
        }
    }
#endif

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
