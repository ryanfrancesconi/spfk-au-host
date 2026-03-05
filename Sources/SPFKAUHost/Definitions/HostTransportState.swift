import AudioToolbox
import Foundation

/// Transport state provided to hosted Audio Units via `AUHostTransportStateBlock`.
///
/// Contains transport flags, playhead position, and cycle boundaries that AUs
/// can use to synchronize with the host's transport.
public struct HostTransportState: Sendable {
    public init() {}

    /// The current state of the transport.
    ///
    /// Flags indicate whether the transport has changed, is moving, recording, or cycling.
    public var flags = AUHostTransportStateFlags()

    /// Current position in the host's timeline, in samples at the audio unit's output sample rate.
    public var currentSamplePosition: Double = 0

    /// The fractional beat number of the cycle (loop) start position.
    public var cycleStartBeatPosition: Double = 0

    /// The fractional beat number of the cycle (loop) end position.
    public var cycleEndBeatPosition: Double = 0
}
