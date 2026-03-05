import Foundation

/// Musical context provided to hosted Audio Units via `AUHostMusicalContextBlock`.
///
/// Contains tempo, time signature, and beat position information that AUs
/// can use to synchronize time-based effects or musical processing.
public struct HostMusicalContext: Sendable {
    public init() {}

    /// The current tempo in beats per minute.
    public var currentTempo: Double = 120

    /// The numerator of the current time signature.
    public var timeSignatureNumerator: Double = 4

    /// The denominator of the current time signature.
    public var timeSignatureDenominator: Int = 4

    /// The precise beat position of the beginning of the current buffer being rendered.
    ///
    /// Calculated as the fractional bar number multiplied by `timeSignatureNumerator`.
    public var currentBeatPosition: Double = 0

    /// The beat position corresponding to the beginning of the current measure.
    public var currentMeasureDownbeatPosition: Double = 0

    /// The number of samples between the beginning of the buffer being rendered and the next beat.
    public var sampleOffsetToNextBeat: Int = 0
}
