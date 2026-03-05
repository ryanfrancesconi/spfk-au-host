import AVFoundation
import Foundation

/// Events emitted during audio unit cache discovery and validation.
public enum AudioUnitCacheEvent: Sendable {
    case cachingStarted
    case cacheUpdated
    case cacheLoaded(SystemComponentsResponse)

    /// Name of AU being currently validated
    case validating(name: String, index: Int, count: Int)
}
