// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

import AudioToolbox
import AVFoundation
import Foundation
import SPFKAudioBase
import SPFKBase
import Testing

@testable import SPFKAUHost

struct CompatibleComponentsTests {
    /// The apps register their own units in process; those are internal and never offered.
    @Test func inProcessSpongeforkUnitsAreNotCompatible() async throws {
        let description = AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: "tcce".fourCC ?? 0,
            componentManufacturer: kAudioUnitManufacturer_Spongefork,
            componentFlags: 0,
            componentFlagsMask: 0
        )

        AUAudioUnit.registerSubclass(AUAudioUnit.self, as: description, name: "Spongefork: Cache Exclusion", version: 1)

        // The component manager's list refreshes after the registration is announced, not during it.
        var isListed = false
        for _ in 0 ..< 100 {
            isListed = !AVAudioUnitComponentManager.shared().components(matching: description).isEmpty
            if isListed { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        try #require(isListed)

        let spongefork = AudioUnitCacheManager.compatibleComponents.filter {
            $0.audioComponentDescription.componentManufacturer == kAudioUnitManufacturer_Spongefork
        }
        #expect(spongefork.isEmpty)
    }
}
