// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

import AudioToolbox
import AVFoundation
import Foundation
import Testing

@testable import SPFKAUHost

struct AudioUnitPresetStorageTests {
    private static let testManufacturer = "Apple"
    private static let testAudioUnitName = "AUDelay"

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("AudioUnitPresetStorageTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    private var sampleState: [String: Any] {
        [
            "name": "TestPreset",
            "version": 1,
            "data": Data([0x01, 0x02, 0x03]),
        ]
    }

    @Test func saveAndLoadRoundTrip() throws {
        let baseDir = try makeTemporaryDirectory()
        defer { cleanup(baseDir) }

        let name = "My Preset"
        try AudioUnitPresetStorage.save(
            name: name,
            fullState: sampleState,
            manufacturer: Self.testManufacturer,
            audioUnitName: Self.testAudioUnitName,
            baseDirectory: baseDir
        )

        let loaded = try AudioUnitPresetStorage.load(
            name: name,
            manufacturer: Self.testManufacturer,
            audioUnitName: Self.testAudioUnitName,
            baseDirectory: baseDir
        )

        #expect(loaded["name"] as? String == "TestPreset")
        #expect(loaded["version"] as? Int == 1)
        #expect(loaded["data"] as? Data == Data([0x01, 0x02, 0x03]))
    }

    @Test func listReturnsSortedNames() throws {
        let baseDir = try makeTemporaryDirectory()
        defer { cleanup(baseDir) }

        let names = ["Zebra", "Alpha", "Middle"]
        for name in names {
            try AudioUnitPresetStorage.save(
                name: name,
                fullState: sampleState,
                manufacturer: Self.testManufacturer,
                audioUnitName: Self.testAudioUnitName,
                baseDirectory: baseDir
            )
        }

        let listed = AudioUnitPresetStorage.list(
            manufacturer: Self.testManufacturer,
            audioUnitName: Self.testAudioUnitName,
            baseDirectory: baseDir
        )
        #expect(listed == ["Alpha", "Middle", "Zebra"])
    }

    @Test func deleteRemovesPreset() throws {
        let baseDir = try makeTemporaryDirectory()
        defer { cleanup(baseDir) }

        let name = "ToDelete"
        try AudioUnitPresetStorage.save(
            name: name,
            fullState: sampleState,
            manufacturer: Self.testManufacturer,
            audioUnitName: Self.testAudioUnitName,
            baseDirectory: baseDir
        )

        #expect(AudioUnitPresetStorage.list(manufacturer: Self.testManufacturer, audioUnitName: Self.testAudioUnitName, baseDirectory: baseDir).count == 1)

        try AudioUnitPresetStorage.delete(name: name, manufacturer: Self.testManufacturer, audioUnitName: Self.testAudioUnitName, baseDirectory: baseDir)

        #expect(AudioUnitPresetStorage.list(manufacturer: Self.testManufacturer, audioUnitName: Self.testAudioUnitName, baseDirectory: baseDir).isEmpty)
    }

    @Test func overwriteExistingPreset() throws {
        let baseDir = try makeTemporaryDirectory()
        defer { cleanup(baseDir) }

        let name = "Overwrite"
        try AudioUnitPresetStorage.save(
            name: name,
            fullState: ["version": 1],
            manufacturer: Self.testManufacturer,
            audioUnitName: Self.testAudioUnitName,
            baseDirectory: baseDir
        )

        try AudioUnitPresetStorage.save(
            name: name,
            fullState: ["version": 2],
            manufacturer: Self.testManufacturer,
            audioUnitName: Self.testAudioUnitName,
            baseDirectory: baseDir
        )

        let loaded = try AudioUnitPresetStorage.load(
            name: name,
            manufacturer: Self.testManufacturer,
            audioUnitName: Self.testAudioUnitName,
            baseDirectory: baseDir
        )

        #expect(loaded["version"] as? Int == 2)
        #expect(AudioUnitPresetStorage.list(manufacturer: Self.testManufacturer, audioUnitName: Self.testAudioUnitName, baseDirectory: baseDir).count == 1)
    }

    @Test func sanitizedFileNames() throws {
        let baseDir = try makeTemporaryDirectory()
        defer { cleanup(baseDir) }

        let name = "Preset/With:Special"
        try AudioUnitPresetStorage.save(
            name: name,
            fullState: sampleState,
            manufacturer: Self.testManufacturer,
            audioUnitName: Self.testAudioUnitName,
            baseDirectory: baseDir
        )

        let loaded = try AudioUnitPresetStorage.load(
            name: name,
            manufacturer: Self.testManufacturer,
            audioUnitName: Self.testAudioUnitName,
            baseDirectory: baseDir
        )

        #expect(loaded["name"] as? String == "TestPreset")
    }

    @Test func listReturnsEmptyForMissingDirectory() {
        let baseDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("nonexistent-\(UUID().uuidString)")

        let listed = AudioUnitPresetStorage.list(
            manufacturer: Self.testManufacturer,
            audioUnitName: Self.testAudioUnitName,
            baseDirectory: baseDir
        )
        #expect(listed.isEmpty)
    }

    @Test func presetsDirectoryCreatesNestedStructure() throws {
        let baseDir = try makeTemporaryDirectory()
        defer { cleanup(baseDir) }

        let directory = try AudioUnitPresetStorage.presetsDirectory(
            manufacturer: "Apple",
            audioUnitName: "AUDelay",
            baseDirectory: baseDir
        )

        #expect(directory.lastPathComponent == "AUDelay")
        #expect(directory.deletingLastPathComponent().lastPathComponent == "Apple")
        #expect(FileManager.default.fileExists(atPath: directory.path))
    }

    @Test func saveAndLoadRealAUFullState() async throws {
        let baseDir = try makeTemporaryDirectory()
        defer { cleanup(baseDir) }

        let avAudioUnit = try await AVAudioUnit.instantiate(
            with: AudioUnitTestContent.auDelayDesc,
            options: []
        )

        let manufacturer = avAudioUnit.auAudioUnit.manufacturerName ?? "Unknown"
        let auName = avAudioUnit.auAudioUnit.audioUnitName ?? "Unknown"

        guard let fullState = avAudioUnit.auAudioUnit.fullState else {
            Issue.record("AUDelay should have a full state")
            return
        }

        try AudioUnitPresetStorage.save(
            name: "Test Preset",
            fullState: fullState,
            manufacturer: manufacturer,
            audioUnitName: auName,
            baseDirectory: baseDir
        )

        let loaded = try AudioUnitPresetStorage.load(
            name: "Test Preset",
            manufacturer: manufacturer,
            audioUnitName: auName,
            baseDirectory: baseDir
        )

        // Verify the loaded state can be applied back
        avAudioUnit.auAudioUnit.fullState = loaded
        #expect(avAudioUnit.auAudioUnit.fullState != nil)
    }

    @Test func saveModifyAndRestoreFullState() async throws {
        let baseDir = try makeTemporaryDirectory()
        defer { cleanup(baseDir) }

        let avAudioUnit = try await AVAudioUnit.instantiate(
            with: AudioUnitTestContent.auDelayDesc,
            options: []
        )

        let manufacturer = avAudioUnit.auAudioUnit.manufacturerName ?? "Unknown"
        let auName = avAudioUnit.auAudioUnit.audioUnitName ?? "Unknown"

        // Capture initial parameter value
        let params = avAudioUnit.auAudioUnit.parameterTree?.allParameters ?? []
        try #require(params.isNotEmpty, "AUDelay should have parameters")

        let originalValue = params[0].value

        // Save the initial state
        guard let fullState = avAudioUnit.auAudioUnit.fullState else {
            Issue.record("AUDelay should have a full state")
            return
        }

        try AudioUnitPresetStorage.save(
            name: "Original",
            fullState: fullState,
            manufacturer: manufacturer,
            audioUnitName: auName,
            baseDirectory: baseDir
        )

        // Modify a parameter
        params[0].value = params[0].minValue

        #expect(params[0].value != originalValue)

        // Restore from saved preset
        let restored = try AudioUnitPresetStorage.load(
            name: "Original",
            manufacturer: manufacturer,
            audioUnitName: auName,
            baseDirectory: baseDir
        )

        avAudioUnit.auAudioUnit.fullState = restored

        // Parameter should be back to original value
        #expect(params[0].value == originalValue)
    }
}
