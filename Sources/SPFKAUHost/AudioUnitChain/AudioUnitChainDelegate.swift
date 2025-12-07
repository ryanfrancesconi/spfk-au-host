// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

public protocol AudioUnitChainDelegate: AudioEngineConnection, AudioUnitAvailability {
    func audioUnitChain(_ audioUnitChain: AudioUnitChain, event: AudioUnitChainEvent)
}
