// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

/// Delegate protocol for receiving events and managing connections within an `AudioUnitChain`.
public protocol AudioUnitChainDelegate: AudioEngineConnection, AudioUnitAvailability {
    func audioUnitChain(_ audioUnitChain: AudioUnitChain, event: AudioUnitChainEvent)
}
