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

        await manager.update(delegate: recorder)
        await manager.update(cacheURL: nil)
        await manager.update(componentProvider: { registry.value })
        await manager.update(componentValidator: { component in
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
}

// MARK: - Helpers

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
