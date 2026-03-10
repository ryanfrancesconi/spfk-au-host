import AVFoundation
import Foundation

/// Events emitted during audio unit cache discovery and validation.
public enum AudioUnitCacheEvent: Sendable {
    case cachingStarted

    /// Progress update: name of the AU just validated, how many completed so far, total count
    case validating(name: String, completed: Int, count: Int)

    /// The cache has be newly written
    case cacheUpdated

    /// Cache is loaded from disk
    case cacheLoaded(SystemComponentsResponse)
}
