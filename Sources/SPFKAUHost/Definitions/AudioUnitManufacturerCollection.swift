// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

import AudioToolbox
import AVFoundation
import Foundation

/// System `AudioComponentDescription` collection grouped by Manufacturer
public struct AudioUnitManufacturerCollection: Equatable, Hashable, Sendable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.manufacturer == rhs.manufacturer
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(manufacturer)
    }

    public let name: String
    public let manufacturer: OSType
    public let components: [SendableAudioUnitComponent]

    public init(
        name: String,
        manufacturer: OSType,
        components: [SendableAudioUnitComponent] = []
    ) {
        self.name = name.trimmed
        self.manufacturer = manufacturer
        self.components = components
    }
}

extension AudioUnitManufacturerCollection {
    public static func createGroup(from components: [AVAudioUnitComponent]) -> [AudioUnitManufacturerCollection] {
        let manufacturerSet = Set(
            components.map {
                AudioUnitManufacturerCollection(
                    name: $0.manufacturerName,
                    manufacturer: $0.audioComponentDescription.componentManufacturer,
                    components: []
                )
            }
        )

        // now fill in the audioUnits

        var componentManufacturers = [AudioUnitManufacturerCollection]()

        for item in manufacturerSet {
            let filtered = filter(components: components, for: item.manufacturer)

            componentManufacturers.append(
                AudioUnitManufacturerCollection(
                    name: item.name,
                    manufacturer: item.manufacturer,
                    components: filtered
                )
            )
        }

        componentManufacturers = componentManufacturers.sorted {
            $0.name.standardCompare(with: $1.name)
        }

        return componentManufacturers
    }

    private static func filter(components: [AVAudioUnitComponent], for manufacturer: OSType) -> [SendableAudioUnitComponent] {
        let components = components.filter {
            $0.audioComponentDescription.componentManufacturer == manufacturer
        }

        let sendables = components.map {
            SendableAudioUnitComponent(avAudioUnitCompoment: $0)
        }

        return sendables.sorted {
            $0.name.standardCompare(with: $1.name)
        }
    }
}
