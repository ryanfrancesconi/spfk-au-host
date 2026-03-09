// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

import AEXML
import AVFoundation
import Foundation
import SPFKBase
import SPFKTesting
import SPFKUtils
import Testing

@testable import SPFKAUHost

@Suite(.serialized, .tags(.development, .realtime))
final class AudioUnitCacheDevelopmentTests: BinTestCase, @unchecked Sendable {
    lazy var manager = AudioUnitCacheManager(cachesDirectory: bin)

    @Test(.disabled("this takes some time so best not to include in automated runs"))
    func createCache() async throws {
        deleteBinOnExit = false

        await manager.update(delegate: self)
        await manager.update(cacheURL: nil) // updates to default

        try await manager.createCache()
    }
}

extension AudioUnitCacheDevelopmentTests: AudioUnitCacheManagerDelegate {
    func handleAudioUnitCacheManager(event: AudioUnitCacheEvent) async {
        Log.default(event)
    }
}
