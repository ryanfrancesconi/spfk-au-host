import AVFoundation
import Foundation

/// Events emitted during audio unit cache discovery and validation.
public enum AudioUnitCacheEvent: Sendable {
    case cachingStarted
    case cacheUpdated
    case cacheLoaded(SystemComponentsResponse)

    /// Progress update: name of the AU just validated, how many completed so far, total count
    case validating(name: String, completed: Int, count: Int)
}
