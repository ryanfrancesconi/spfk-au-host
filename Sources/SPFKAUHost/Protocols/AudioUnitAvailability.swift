// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

import AVFoundation
import Foundation
import SPFKBase

/// Protocol for types that provide a list of available Audio Unit components and manufacturer groupings.
public protocol AudioUnitAvailability {
    var availableAudioUnitComponents: [AVAudioUnitComponent]? { get }
    var audioUnitManufacturerCollection: [AudioUnitManufacturerCollection] { get }
}
