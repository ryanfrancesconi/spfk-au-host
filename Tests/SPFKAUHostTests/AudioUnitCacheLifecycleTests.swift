// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

@preconcurrency import AVFoundation
import Foundation
import SPFKAudioBase
import SPFKBase
import SPFKTesting
import Testing

@testable import SPFKAUHost

/// Scans run against a component list the test controls and a validator that touches no plugin,
/// so a lifecycle test validates nothing real.
@Suite(.serialized, .tags(.file, .audioUnit))
final class AudioUnitCacheLifecycleTests: BinTestCase, @unchecked Sendable {
    lazy var manager = AudioUnitCacheManager(cachesDirectory: bin)
    let recorder = EventRecorder()
    let validated = Locked<[String]>([])
    /// The `forceExternal` the validator was last called with.
    let forced = Locked(false)
    let registry: Locked<[AVAudioUnitComponent]>

    /// Apple components, which the test registry hands out in this order.
    let components: [AVAudioUnitComponent]

    override init() async {
        components = AudioUnitCacheManager.compatibleComponents
            .filter { $0.audioComponentDescription.componentManufacturer == kAudioUnitManufacturer_Apple }
            .sorted { $0.audioComponentDescription.uid < $1.audioComponentDescription.uid }

        registry = Locked(Array(components.prefix(Self.initialCount)))

        await super.init()
    }

    /// Enough that a scan has results left after the first, since the scan loop checks for
    /// cancellation only when the next result arrives.
    static let initialCount = 5

    func setUp() async throws {
        try #require(components.count > Self.initialCount, "needs \(Self.initialCount + 1) Apple components")

        let registry = registry
        let validated = validated
        let forced = forced

        await manager.update(delegate: recorder)
        await manager.update(cacheURL: nil)
        await manager.update(componentProvider: { registry.value })
        await manager.update(componentValidator: { component, forceExternal in
            forced.mutate { $0 = forceExternal }
            validated.mutate { $0.append(component.audioComponentDescription.uid) }
            return ComponentValidationResult(
                audioComponentDescription: component.audioComponentDescription,
                component: component,
                validation: AudioUnitValidator.ValidationResult(result: .passed)
            )
        })
    }

    func tearDown() async {
        await manager.dispose()
    }

    // MARK: - Tests

    @Test func fullScanLeavesNothingToRevalidate() async throws {
        try await setUp()
        defer { await tearDown() }

        try await manager.createCache()
        #expect(await manager.validationIsNeeded == false)

        let before = recorder.validatingCount
        try await manager.updateCache()
        #expect(recorder.validatingCount == before)
    }

    @Test func cancelledScanKeepsPreviousCache() async throws {
        try await setUp()
        defer { await tearDown() }

        try await manager.createCache()
        let url = try #require(await manager.cacheURL)
        #expect(url.exists)

        let manager = manager
        recorder.onEvent = { event in
            if case .validating(_, completed: 1, _) = event {
                await manager.cancelScan()
            }
        }

        await #expect(throws: CancellationError.self) {
            try await manager.createCache()
        }

        #expect(url.exists)
    }

    @Test func componentRegisteredMidScanIsValidated() async throws {
        try await setUp()
        defer { await tearDown() }

        let extra = components[Self.initialCount]
        let uid = extra.audioComponentDescription.uid
        let registry = registry
        let registered = Locked(false)
        let manager = manager

        recorder.onEvent = { event in
            guard case .validating = event, !registered.value else { return }
            registered.mutate { $0 = true }
            registry.mutate { $0.append(extra) }
            await manager.handleComponentRegistrationsChanged()
        }

        try await manager.createCache()

        #expect(validated.value.contains(uid))
        #expect(await manager.componentCollection?.validationResults.contains { $0.audioComponentDescription.uid == uid } == true)
    }

    @Test func forcedRescanReachesTheValidator() async throws {
        try await setUp()
        defer { await tearDown() }

        try await manager.createCache(forceExternal: true)
        #expect(forced.value == true)

        try await manager.createCache()
        #expect(forced.value == false)
    }

    // MARK: - One scan at a time

    /// Holds every validation until the test opens the gate.
    func useGatedValidator(_ gate: Gate) async {
        await manager.update(componentValidator: { component, _ in
            await gate.wait()
            return ComponentValidationResult(
                audioComponentDescription: component.audioComponentDescription,
                component: component,
                validation: AudioUnitValidator.ValidationResult(result: .passed)
            )
        })
    }

    @Test func overlappingScansRunOneAtATime() async throws {
        try await setUp()
        defer { await tearDown() }

        let gate = Gate()
        await useGatedValidator(gate)

        let manager = manager
        let first = Task { try await manager.createCache() }
        #expect(await poll { gate.waiting > 0 })

        let second = Task { try await manager.createCache() }
        try await Task.sleep(for: .milliseconds(200))
        #expect(recorder.cachingStartedCount == 1)

        gate.open()
        try await first.value
        try await second.value
        #expect(recorder.cachingStartedCount == 2)
    }

    @Test func disposeWaitsForTheScan() async throws {
        try await setUp()
        defer { await tearDown() }

        let gate = Gate()
        await useGatedValidator(gate)

        let manager = manager
        let scan = Task { try await manager.createCache() }
        #expect(await poll { gate.waiting > 0 })

        let disposed = Locked(false)
        let disposal = Task {
            await manager.dispose()
            disposed.mutate { $0 = true }
        }

        try await Task.sleep(for: .milliseconds(200))
        #expect(disposed.value == false)

        gate.open()
        await disposal.value
        #expect(await manager.isScanning == false)
        _ = await scan.result
    }

    @Test func cancelledRegistrationUpdateSendsNoError() async throws {
        try await setUp()
        defer { await tearDown() }

        let added = 4
        try #require(components.count >= Self.initialCount + added)

        try await manager.createCache()

        let manager = manager
        recorder.onEvent = { event in
            if case .validating(_, completed: 1, _) = event {
                await manager.cancelScan()
            }
        }

        let components = components
        registry.mutate { $0.append(contentsOf: components[Self.initialCount ..< Self.initialCount + added]) }
        await manager.handleComponentRegistrationsChanged()

        #expect(recorder.errors.isEmpty)
    }
}

// MARK: - Helpers

/// Polls `condition` until it holds or `timeout` passes, and returns whether it held.
func poll(timeout: Duration = .seconds(5), _ condition: () async -> Bool) async -> Bool {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if await condition() { return true }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return await condition()
}

/// Suspends callers of `wait()` until `open()`, ignoring cancellation as a blocking validation does.
final class Gate: @unchecked Sendable {
    private let lock = NSLock()
    private var isOpen = false
    private var continuations: [CheckedContinuation<Void, Never>] = []

    var waiting: Int {
        lock.withLock { continuations.count }
    }

    func wait() async {
        await withCheckedContinuation { continuation in
            let resumeNow = lock.withLock {
                if isOpen { return true }
                continuations.append(continuation)
                return false
            }
            if resumeNow { continuation.resume() }
        }
    }

    func open() {
        let waiting = lock.withLock {
            isOpen = true
            defer { continuations = [] }
            return continuations
        }
        waiting.forEach { $0.resume() }
    }
}

/// A value shared between a test and the closures it hands the manager.
final class Locked<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: Value

    init(_ value: Value) {
        _value = value
    }

    var value: Value {
        lock.withLock { _value }
    }

    func mutate(_ body: (inout Value) -> Void) {
        lock.withLock { body(&_value) }
    }
}

final class EventRecorder: AudioUnitCacheManagerDelegate, @unchecked Sendable {
    private let events = Locked<[AudioUnitCacheEvent]>([])
    private let handler = Locked<(@Sendable (AudioUnitCacheEvent) async -> Void)?>(nil)

    /// Runs inside the manager's `send`, so the scan waits for it.
    var onEvent: (@Sendable (AudioUnitCacheEvent) async -> Void)? {
        get { handler.value }
        set { handler.mutate { $0 = newValue } }
    }

    func handleAudioUnitCacheManager(event: AudioUnitCacheEvent) async {
        events.mutate { $0.append(event) }
        await onEvent?(event)
    }

    var validatingCount: Int {
        events.value.count(where: { if case .validating = $0 { true } else { false } })
    }

    var cachingStartedCount: Int {
        events.value.count(where: { if case .cachingStarted = $0 { true } else { false } })
    }

    var errors: [String] {
        events.value.compactMap { if case let .error(message) = $0 { message } else { nil } }
    }
}
