// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

import AudioToolbox
import AVFoundation
import Foundation

/// System `AudioComponentDescription` collection grouped by Manufacturer
public struct AudioUnitManufacturerCollection: Equatable, Hashable, Sendable {
    /// Equality is determined by matching the manufacturer identifier.
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.manufacturer == rhs.manufacturer
    }

    /// Hashes by manufacturer and name.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(manufacturer)
        hasher.combine(name)
    }

    /// The display name of the manufacturer.
    public let name: String

    /// The four-character manufacturer code.
    public let manufacturer: OSType

    /// The audio unit components belonging to this manufacturer.
    public let components: [S_AVAudioUnitComponent]

    /// Creates a manufacturer collection with the given name, manufacturer code, and components.
    public init(
        name: String,
        manufacturer: OSType,
        components: [S_AVAudioUnitComponent] = []
    ) {
        self.name = name.trimmed
        self.manufacturer = manufacturer
        self.components = components
    }
}

extension AudioUnitManufacturerCollection {
    /// Groups the given audio unit components by manufacturer and returns a sorted array of collections.
    public static func createGroup(from components: [AVAudioUnitComponent]) -> [AudioUnitManufacturerCollection] {
        let manufacturerSet = Set(
            components.map {
                AudioUnitManufacturerCollection(
                    name: $0.manufacturerName,
                    manufacturer: $0.audioComponentDescription.componentManufacturer,
                )
            })

        // now fill in the audioUnits

        var value = [AudioUnitManufacturerCollection]()

        for item in manufacturerSet {
            let mComponents = select(components: components, for: item.manufacturer)

            value.append(
                AudioUnitManufacturerCollection(
                    name: item.name,
                    manufacturer: item.manufacturer,
                    components: mComponents
                )
            )
        }

        value = value.sorted {
            $0.name.standardCompare(with: $1.name)
        }

        return value
    }

    private static func select(components: [AVAudioUnitComponent], for manufacturer: OSType) -> [S_AVAudioUnitComponent] {
        let components = components.filter {
            $0.audioComponentDescription.componentManufacturer == manufacturer
        }

        let sendables = components.map {
            S_AVAudioUnitComponent(avAudioUnitComponent: $0)
        }

        return sendables.sorted {
            $0.name.standardCompare(with: $1.name)
        }
    }
}
