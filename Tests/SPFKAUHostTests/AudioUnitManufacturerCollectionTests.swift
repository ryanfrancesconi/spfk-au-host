import AudioToolbox
import AVFoundation
import Foundation
import Testing

@testable import SPFKAUHost

struct AudioUnitManufacturerCollectionTests {
    @Test func initWithDefaults() {
        let collection = AudioUnitManufacturerCollection(
            name: "Apple",
            manufacturer: 1_634_758_764
        )

        #expect(collection.name == "Apple")
        #expect(collection.manufacturer == 1_634_758_764)
        #expect(collection.components.isEmpty)
    }

    @Test func equalityByManufacturer() {
        let a = AudioUnitManufacturerCollection(
            name: "Apple",
            manufacturer: 1_634_758_764
        )
        let b = AudioUnitManufacturerCollection(
            name: "Apple Inc.",
            manufacturer: 1_634_758_764
        )

        #expect(a == b)
    }

    @Test func inequalityByManufacturer() {
        let a = AudioUnitManufacturerCollection(
            name: "Apple",
            manufacturer: 1_634_758_764
        )
        let b = AudioUnitManufacturerCollection(
            name: "Waves",
            manufacturer: 1_802_721_110
        )

        #expect(a != b)
    }

    @Test func hashable() {
        let a = AudioUnitManufacturerCollection(
            name: "Apple",
            manufacturer: 1_634_758_764
        )
        let b = AudioUnitManufacturerCollection(
            name: "Apple",
            manufacturer: 1_634_758_764
        )

        var set = Set<AudioUnitManufacturerCollection>()
        set.insert(a)
        set.insert(b)

        // Same manufacturer, same name => same hash
        #expect(set.count == 1)
    }

    @Test func createGroupFromComponents() {
        let components = TestAudioUnitContent.components

        guard components.count >= 2 else {
            Issue.record("Need at least 2 components for test")
            return
        }

        let groups = AudioUnitManufacturerCollection.createGroup(from: components)

        #expect(!groups.isEmpty)

        // Groups should be sorted by name
        for i in 1 ..< groups.count {
            #expect(groups[i - 1].name <= groups[i].name)
        }
    }

    @Test func createGroupGroupsByManufacturer() {
        let components = TestAudioUnitContent.components

        let groups = AudioUnitManufacturerCollection.createGroup(from: components)

        // Each group should have components only from one manufacturer
        for group in groups {
            for component in group.components {
                #expect(component.audioComponentDescription.componentManufacturer == group.manufacturer)
            }
        }
    }

    @Test func createGroupComponentsSortedByName() {
        let components = TestAudioUnitContent.components

        let groups = AudioUnitManufacturerCollection.createGroup(from: components)

        for group in groups where group.components.count > 1 {
            for i in 1 ..< group.components.count {
                // Components within a group should be sorted
                #expect(group.components[i - 1].name <= group.components[i].name)
            }
        }
    }

    @Test func createGroupFromEmptyArray() {
        let groups = AudioUnitManufacturerCollection.createGroup(from: [])
        #expect(groups.isEmpty)
    }
}
