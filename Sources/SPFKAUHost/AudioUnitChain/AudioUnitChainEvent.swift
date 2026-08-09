// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

import Foundation

/// The events this actor will generate
public enum AudioUnitChainEvent: Sendable {
    case connectionError(error: Error)

    case willBypass(index: Int, isBypassed: Bool)
    case didBypass(index: Int, isBypassed: Bool)

    case willRemove(index: Int)
    case didRemove(index: Int)

    case willInsert(index: Int)
    case didInsert(index: Int)

    case effectMoved(from: Int, to: Int)

    /// A slot could not be reinstated by `restore`. The slot is left empty.
    case restoreFailed(index: Int, error: Error)

    /// An empty slot was appended. `count` is the new total insert count.
    case didAppendInsert(count: Int)
    /// The last empty slot was removed. `count` is the new total insert count.
    case didRemoveInsert(count: Int)
}
