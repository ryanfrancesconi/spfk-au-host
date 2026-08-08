// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

import Foundation
import SPFKBase
import SPFKTesting
import Testing

@testable import SPFKAUHost

/// The cache directory and the cache URL are set by two separate calls, and a host has no
/// reason to know which order they need to happen in.
@Suite(.tags(.file))
final class AudioUnitCacheURLTests: BinTestCase, @unchecked Sendable {
    override init() async {
        await super.init()
    }

    @Test func directorySetAfterCacheURLStillResolves() async throws {
        let manager = AudioUnitCacheManager()

        // Nothing to derive a default from yet.
        await manager.update(cacheURL: nil)
        await #expect(manager.cacheURL == nil)

        await manager.update(cachesDirectory: bin)

        let cacheURL = try #require(await manager.cacheURL)
        #expect(cacheURL.deletingLastPathComponent() == bin.resolvingSymlinksInPath())

        await manager.dispose()
    }

    @Test func directorySetBeforeCacheURLResolves() async throws {
        let manager = AudioUnitCacheManager()

        await manager.update(cachesDirectory: bin)
        await manager.update(cacheURL: nil)

        let cacheURL = try #require(await manager.cacheURL)
        #expect(cacheURL.deletingLastPathComponent() == bin.resolvingSymlinksInPath())

        await manager.dispose()
    }

    @Test func explicitCacheURLSurvivesADirectoryChange() async throws {
        let manager = AudioUnitCacheManager()
        let explicit = bin.appendingPathComponent("Custom.json")

        await manager.update(cacheURL: explicit)
        await manager.update(cachesDirectory: bin.appendingPathComponent("Elsewhere"))

        await #expect(manager.cacheURL == explicit)

        await manager.dispose()
    }
}
