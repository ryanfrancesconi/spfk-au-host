// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-audio

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
}
