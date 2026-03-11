// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

import Foundation

/// File-based audio unit preset storage for sandboxed applications.
///
/// Stores presets as `.aupreset` plist files within a caller-provided base directory,
/// using the same folder structure as `~/Library/Audio/Presets/`:
/// ```
/// {baseDirectory}/{manufacturer}/{audioUnitName}/{presetName}.aupreset
/// ```
///
/// Users can manually copy `.aupreset` files from `~/Library/Audio/Presets/`
/// into the app's storage directory to make them available in the sandboxed app.
public enum AudioUnitPresetStorage {
    /// Saves an audio unit's full state as a preset file.
    /// - Parameters:
    ///   - name: The preset name (used as the file name).
    ///   - fullState: The `AUAudioUnit.fullState` dictionary to persist.
    ///   - manufacturer: The audio unit's manufacturer name.
    ///   - audioUnitName: The audio unit's name.
    ///   - baseDirectory: The root directory for preset storage.
    public static func save(
        name: String,
        fullState: [String: Any],
        manufacturer: String,
        audioUnitName: String,
        baseDirectory: URL
    ) throws {
        let directory = try presetsDirectory(
            manufacturer: manufacturer,
            audioUnitName: audioUnitName,
            baseDirectory: baseDirectory
        )
        let fileURL = directory.appendingPathComponent(sanitizedFileName(name))

        let data = try PropertyListSerialization.data(
            fromPropertyList: fullState,
            format: .xml,
            options: 0
        )

        try data.write(to: fileURL, options: .atomic)
    }

    /// Loads a preset's full state dictionary from disk.
    /// - Parameters:
    ///   - name: The preset name.
    ///   - manufacturer: The audio unit's manufacturer name.
    ///   - audioUnitName: The audio unit's name.
    ///   - baseDirectory: The root directory for preset storage.
    /// - Returns: The full state dictionary suitable for `AUAudioUnit.fullState`.
    public static func load(
        name: String,
        manufacturer: String,
        audioUnitName: String,
        baseDirectory: URL
    ) throws -> [String: Any] {
        let directory = baseDirectory
            .appendingPathComponent(manufacturer)
            .appendingPathComponent(audioUnitName)
        let fileURL = directory.appendingPathComponent(sanitizedFileName(name))

        let data = try Data(contentsOf: fileURL)

        guard let plist = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        ) as? [String: Any] else {
            throw CocoaError(.fileReadCorruptFile)
        }

        return plist
    }

    /// Deletes a preset file from disk.
    /// - Parameters:
    ///   - name: The preset name.
    ///   - manufacturer: The audio unit's manufacturer name.
    ///   - audioUnitName: The audio unit's name.
    ///   - baseDirectory: The root directory for preset storage.
    public static func delete(
        name: String,
        manufacturer: String,
        audioUnitName: String,
        baseDirectory: URL
    ) throws {
        let directory = baseDirectory
            .appendingPathComponent(manufacturer)
            .appendingPathComponent(audioUnitName)
        let fileURL = directory.appendingPathComponent(sanitizedFileName(name))

        try FileManager.default.removeItem(at: fileURL)
    }

    /// Lists all preset names for a given audio unit, sorted alphabetically.
    /// - Parameters:
    ///   - manufacturer: The audio unit's manufacturer name.
    ///   - audioUnitName: The audio unit's name.
    ///   - baseDirectory: The root directory for preset storage.
    /// - Returns: Sorted array of preset names (without the `.aupreset` extension).
    public static func list(
        manufacturer: String,
        audioUnitName: String,
        baseDirectory: URL
    ) -> [String] {
        let directory = baseDirectory
            .appendingPathComponent(manufacturer)
            .appendingPathComponent(audioUnitName)

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else {
            return []
        }

        return contents
            .filter { $0.pathExtension == "aupreset" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    /// Returns the preset directory for a given audio unit, creating it if necessary.
    public static func presetsDirectory(
        manufacturer: String,
        audioUnitName: String,
        baseDirectory: URL
    ) throws -> URL {
        let directory = baseDirectory
            .appendingPathComponent(manufacturer)
            .appendingPathComponent(audioUnitName)

        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        }

        return directory
    }

    // MARK: - Private

    private static func sanitizedFileName(_ name: String) -> String {
        let sanitized = name
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return sanitized + ".aupreset"
    }
}
