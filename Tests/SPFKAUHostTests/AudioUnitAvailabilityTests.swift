// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

import AVFoundation
import Foundation
import SPFKAUHost
import SPFKBase
import SPFKTesting
import Testing

final class AudioUnitAvailabilityTests: TestCaseModel {
    let dummyEngine = TestAudioUnitContent()

    init() async throws {}

    @Test func findEffects() async throws {
        #expect(dummyEngine.availableAudioUnitComponents?.count == 5)
    }

    @Test func manufacturerCollection() async throws {
        let collection = dummyEngine.audioUnitManufactererCollection

        #expect(dummyEngine.audioUnitManufactererCollection.count == 2)
        #expect(collection.first?.components.count == 4)

        for company in collection {
            Log.debug(company.name, company.components.map { "\($0.name)" })
        }
    }
}
