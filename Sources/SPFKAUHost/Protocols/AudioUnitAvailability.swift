// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

import AVFoundation
import Foundation
import SPFKBase

public protocol AudioUnitAvailability {
    var availableAudioUnitComponents: [AVAudioUnitComponent]? { get }
    var audioUnitManufacturerCollection: [AudioUnitManufacturerCollection] { get }
}
