// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

import AVFoundation
import Foundation
import SPFKAudioBase
import SPFKBase
import SPFKTesting
import SPFKUtils
import Testing

@testable import SPFKAUHost

@Suite(.serialized, .tags(.realtime))
final class AudioUnitCacheTests: BinTestCase, @unchecked Sendable {
    lazy var manager = AudioUnitCacheManager(cachesDirectory: bin)

    override init() async {
        await super.init()
    }

    func tearDown() async throws {
        await manager.dispose()
    }

    let cacheJSON = """
    {
        "cachedComponentUIDs": ["61756678687368666170706c", "6175667864656c796170706c"],
        "audioUnits": [
            {
                "name": "AUHighShelfFilter",
                "manufacturerName": "Apple",
                "typeName": "Effect",
                "version": "1.6.0",
                "componentType": 1635083896,
                "componentSubType": 1752393830,
                "componentManufacturer": 1634758764,
                "componentFlags": 2,
                "componentFlagsMask": 0,
                "validation": "Passed",
                "isEnabled": true
            },
            {
                "name": "AUDelay",
                "manufacturerName": "Apple",
                "typeName": "Effect",
                "version": "1.6.0",
                "componentType": 1635083896,
                "componentSubType": 1684368505,
                "componentManufacturer": 1634758764,
                "componentFlags": 2,
                "componentFlagsMask": 0,
                "validation": "Passed",
                "isEnabled": true
            }
        ]
    }
    """

    // MARK: - Parse

    @Test func parseCache() async throws {
        let cacheURL = bin.appendingPathComponent("AudioUnitCache.json")
        try cacheJSON.write(to: cacheURL, atomically: true, encoding: .utf8)

        await manager.update(cacheURL: cacheURL)

        let response = try await manager.loadCache()

        Log.debug(response.results.map(\.description))

        #expect(response.results.map(\.name) == ["AUHighShelfFilter", "AUDelay"])

        try await tearDown()
    }

    @Test func parseCacheRestoresUIDs() async throws {
        let cacheURL = bin.appendingPathComponent("AudioUnitCache.json")
        try cacheJSON.write(to: cacheURL, atomically: true, encoding: .utf8)

        await manager.update(cacheURL: cacheURL)

        _ = try await manager.loadCache()

        let uids = await manager.cachedComponentUIDs
        #expect(uids == Set(["61756678687368666170706c", "6175667864656c796170706c"]))

        try await tearDown()
    }

    @Test func parseCacheRestoresValidation() async throws {
        let json = """
        {
            "cachedComponentUIDs": [],
            "audioUnits": [
                {
                    "name": "FailedAU",
                    "manufacturerName": "Test",
                    "typeName": "Effect",
                    "version": "1.0",
                    "componentType": 0,
                    "componentSubType": 0,
                    "componentManufacturer": 0,
                    "componentFlags": 0,
                    "componentFlagsMask": 0,
                    "validation": "Failed",
                    "isEnabled": false
                }
            ]
        }
        """

        let cacheURL = bin.appendingPathComponent("AudioUnitCache.json")
        try json.write(to: cacheURL, atomically: true, encoding: .utf8)
        await manager.update(cacheURL: cacheURL)

        let response = try await manager.loadCache()

        let result = try #require(response.results.first)
        #expect(result.validation.result == .failed)
        #expect(result.isEnabled == false)
        #expect(result.name == "FailedAU")
        #expect(result.manufacturerName == "Test")

        try await tearDown()
    }

    // MARK: - Validation Is Needed

    @Test func validationIsNeededWhenUIDsMatch() async throws {
        let cacheURL = bin.appendingPathComponent("AudioUnitCache.json")

        // Build UIDs from the actual system compatible components
        let systemUIDs = AudioUnitCacheManager.compatibleComponents
            .map(\.audioComponentDescription.uid)
            .sorted()

        let json = """
        {
            "cachedComponentUIDs": \(jsonArray(systemUIDs)),
            "audioUnits": []
        }
        """

        try json.write(to: cacheURL, atomically: true, encoding: .utf8)
        await manager.update(cacheURL: cacheURL)

        _ = try await manager.loadCache()

        let needed = await manager.validationIsNeeded
        #expect(needed == false)

        try await tearDown()
    }

    @Test func validationIsNeededWhenUIDsDiffer() async throws {
        let cacheURL = bin.appendingPathComponent("AudioUnitCache.json")

        let json = """
        {
            "cachedComponentUIDs": ["bogus_uid_1", "bogus_uid_2"],
            "audioUnits": []
        }
        """

        try json.write(to: cacheURL, atomically: true, encoding: .utf8)
        await manager.update(cacheURL: cacheURL)

        _ = try await manager.loadCache()

        let needed = await manager.validationIsNeeded
        #expect(needed == true)

        try await tearDown()
    }

    @Test func validationIsNeededWhenUIDsNil() async throws {
        // cachedComponentUIDs is nil before loadCache is called
        let needed = await manager.validationIsNeeded
        #expect(needed == true)

        try await tearDown()
    }

    // MARK: - Write + Round-Trip

    @Test func writeCacheRoundTrip() async throws {
        await manager.update(delegate: self)
        await manager.update(cacheURL: nil)

        let desc = AudioComponentDescription(
            componentType: 1635083896,
            componentSubType: 1684368505,
            componentManufacturer: 1634758764,
            componentFlags: 2,
            componentFlagsMask: 0
        )

        let validation = AudioUnitValidator.ValidationResult(result: .passed)
        let result = ComponentValidationResult(
            audioComponentDescription: desc,
            validation: validation,
            isEnabled: false,
            name: "TestAU",
            typeName: "Effect",
            manufacturerName: "TestMfg",
            versionString: "2.0"
        )

        let collection = ComponentCollection(results: [result])
        await manager.update(componentCollection: collection)

        try await manager.writeCache()

        // Read back
        let response = try await manager.loadCache()

        let loaded = try #require(response.results.first)
        #expect(loaded.name == "TestAU")
        #expect(loaded.manufacturerName == "TestMfg")
        #expect(loaded.typeName == "Effect")
        #expect(loaded.versionString == "2.0")
        #expect(loaded.isEnabled == false)
        #expect(loaded.validation.result == .passed)

        // Verify UIDs were persisted
        let uids = await manager.cachedComponentUIDs
        #expect(uids != nil)
        #expect(uids?.isEmpty == false)

        try await tearDown()
    }

    @Test func writeCacheSerializesJSON() async throws {
        await manager.update(delegate: self)
        await manager.update(cacheURL: nil)

        let desc = AudioComponentDescription(
            componentType: 1635083896,
            componentSubType: 1684368505,
            componentManufacturer: 1634758764,
            componentFlags: 0,
            componentFlagsMask: 0
        )

        let validation = AudioUnitValidator.ValidationResult(result: .timedOut)
        let result = ComponentValidationResult(
            audioComponentDescription: desc,
            validation: validation,
            name: "TimeoutAU",
            typeName: "Effect",
            manufacturerName: "Vendor",
            versionString: "1.0"
        )

        await manager.update(componentCollection: ComponentCollection(results: [result]))

        try await manager.writeCache()

        let cacheURL = await manager.cacheURL
        let url = try #require(cacheURL)
        let data = try Data(contentsOf: url)
        let json = try #require(String(data: data, encoding: .utf8))

        #expect(json.contains("\"cachedComponentUIDs\""))
        #expect(json.contains("\"audioUnits\""))
        #expect(json.contains("TimeoutAU"))
        #expect(json.contains("Timed out"))

        try await tearDown()
    }

    // MARK: - Remove Cache

    @Test func removeCache() async throws {
        await manager.update(delegate: self)
        await manager.update(cacheURL: nil)

        let cacheURL = await manager.cacheURL
        let url = try #require(cacheURL)

        // Write something
        try "test".write(to: url, atomically: true, encoding: .utf8)
        #expect(url.exists)

        await manager.removeCache()
        #expect(!url.exists)

        try await tearDown()
    }

    // MARK: - Load Lifecycle

    @Test func loadSetsComponentCollectionAndStartsObservation() async throws {
        await manager.update(delegate: self)

        let cacheURL = bin.appendingPathComponent("AudioUnitCache.json")
        try cacheJSON.write(to: cacheURL, atomically: true, encoding: .utf8)
        await manager.update(cacheURL: cacheURL)

        try await manager.load()

        let collection = await manager.componentCollection
        #expect(collection != nil)
        #expect(collection?.isEmpty == false)

        let isObserving = await manager.isCacheObserving
        #expect(isObserving == true)

        try await tearDown()
    }

    // MARK: - Helpers

    private func jsonArray(_ values: [String]) -> String {
        let items = values.map { "\"\($0)\"" }.joined(separator: ", ")
        return "[\(items)]"
    }
}

extension AudioUnitCacheTests: AudioUnitCacheManagerDelegate {
    func handleAudioUnitCacheManager(event: AudioUnitCacheEvent) async {
        Log.debug(event)
    }
}
