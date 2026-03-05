// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

import AudioToolbox
import SwiftExtensions

/// Provides musical context and transport state blocks to hosted Audio Units.
///
/// `HostAUState` is a reference type so that the blocks returned by ``musicalContextBlock``
/// and ``transportStateBlock`` always read the **current** values of ``musicalContext``
/// and ``transportState``. Mutating those properties after the blocks have been assigned
/// to an `AUAudioUnit` will be reflected on the next render cycle without reassignment.
public final class HostAUState {
    public init() {}

    public var isEnabled: Bool = true

    public var musicalContext = HostMusicalContext()
    public var transportState = HostTransportState()

    public var musicalContextBlock: AUHostMusicalContextBlock {
        /**  @typedef    AUHostMusicalContextBlock
             @brief        Block by which hosts provide musical tempo, time signature, and beat position.
             @param    currentTempo
                 The current tempo in beats per minute.
             @param    timeSignatureNumerator
                 The numerator of the current time signature.
             @param    timeSignatureDenominator
                 The denominator of the current time signature.
             @param    currentBeatPosition
                 The precise beat position of the beginning of the current buffer being rendered.
             @param    sampleOffsetToNextBeat
                 The number of samples between the beginning of the buffer being rendered and the next beat
                 (can be 0).
             @param    currentMeasureDownbeatPosition
                 The beat position corresponding to the beginning of the current measure.
             @return
                 YES for success.
         */
        { [self] currentTempo, timeSignatureNumerator, timeSignatureDenominator,
            currentBeatPosition, sampleOffsetToNextBeat, currentMeasureDownbeatPosition in

            currentTempo?.pointee = musicalContext.currentTempo
            timeSignatureNumerator?.pointee = musicalContext.timeSignatureNumerator
            timeSignatureDenominator?.pointee = musicalContext.timeSignatureDenominator
            currentBeatPosition?.pointee = musicalContext.currentBeatPosition
            sampleOffsetToNextBeat?.pointee = musicalContext.sampleOffsetToNextBeat
            currentMeasureDownbeatPosition?.pointee = musicalContext.currentMeasureDownbeatPosition

            return true
        }
    }

    public var transportStateBlock: AUHostTransportStateBlock {
        /**  @typedef    AUHostTransportStateBlock
             @brief        Block by which hosts provide information about their transport state.
             @param    transportStateFlags
                 The current state of the transport.
             @param    currentSamplePosition
                 The current position in the host's timeline, in samples at the audio unit's output sample
                 rate.
             @param    cycleStartBeatPosition
                 If cycling, the starting beat position of the cycle.
             @param    cycleEndBeatPosition
                 If cycling, the ending beat position of the cycle.
             @discussion
                 If the host app provides this block to an AUAudioUnit (as its transportStateBlock), then
                 the block may be called at the beginning of each render cycle to obtain information about
                 the current transport state.

                 Any of the provided parameters may be null to indicate that the audio unit is not interested
                 in that particular piece of information.
         */
        { [self] transportStateFlags, currentSamplePosition,
            cycleStartBeatPosition, cycleEndBeatPosition in

            transportStateFlags?.pointee = transportState.flags
            currentSamplePosition?.pointee = transportState.currentSamplePosition
            cycleStartBeatPosition?.pointee = transportState.cycleStartBeatPosition
            cycleEndBeatPosition?.pointee = transportState.cycleEndBeatPosition
            return true
        }
    }
}
