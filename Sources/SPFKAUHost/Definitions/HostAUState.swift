// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

import AudioToolbox
import SwiftExtensions

/// Provides musical context and transport state blocks to hosted Audio Units.
///
/// `HostAUState` is a reference type so that the blocks returned by ``musicalContextBlock``
/// and ``transportStateBlock`` always read the **current** values of ``musicalContext``
/// and ``transportState``. Mutating those properties after the blocks have been assigned
/// to an `AUAudioUnit` will be reflected on the next render cycle without reassignment.
public final class HostAUState: @unchecked Sendable {
    public init() {}

    /// Whether the host state blocks should provide data to Audio Units.
    public var isEnabled: Bool = true

    /// The musical context (tempo, time signature, beat position) to provide to hosted AUs.
    public var musicalContext = HostMusicalContext()

    /// The transport state (flags, sample position, cycle boundaries) to provide to hosted AUs.
    public var transportState = HostTransportState()

    /// A block that provides the current ``musicalContext`` values to an `AUAudioUnit`.
    ///
    /// Assign this to `AUAudioUnit.musicalContextBlock`. Allocated once; the block captures
    /// `self` so it always reads the latest values from ``musicalContext`` without reallocation.
    public lazy var musicalContextBlock: AUHostMusicalContextBlock = {
        [self] currentTempo, timeSignatureNumerator, timeSignatureDenominator,
        currentBeatPosition, sampleOffsetToNextBeat, currentMeasureDownbeatPosition in

        currentTempo?.pointee = musicalContext.currentTempo
        timeSignatureNumerator?.pointee = musicalContext.timeSignatureNumerator
        timeSignatureDenominator?.pointee = musicalContext.timeSignatureDenominator
        currentBeatPosition?.pointee = musicalContext.currentBeatPosition
        sampleOffsetToNextBeat?.pointee = musicalContext.sampleOffsetToNextBeat
        currentMeasureDownbeatPosition?.pointee = musicalContext.currentMeasureDownbeatPosition

        return true
    }

    /// A block that provides the current ``transportState`` values to an `AUAudioUnit`.
    ///
    /// Assign this to `AUAudioUnit.transportStateBlock`. Allocated once; the block captures
    /// `self` so it always reads the latest values from ``transportState`` without reallocation.
    public lazy var transportStateBlock: AUHostTransportStateBlock = {
        [self] transportStateFlags, currentSamplePosition,
        cycleStartBeatPosition, cycleEndBeatPosition in

        transportStateFlags?.pointee = transportState.flags
        currentSamplePosition?.pointee = transportState.currentSamplePosition
        cycleStartBeatPosition?.pointee = transportState.cycleStartBeatPosition
        cycleEndBeatPosition?.pointee = transportState.cycleEndBeatPosition
        return true
    }
}
