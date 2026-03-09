// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

import AEXML
import AudioToolbox
@preconcurrency import AVFoundation
import Foundation
import SPFKUtils

/// Manages loading and locating audio unit presets, including user presets on disk.
public enum AudioUnitPresets {
    #if os(macOS)
        /// File system locations for user audio unit presets.
        public enum Locations {
            static var userPresets: URL {
                URL(fileURLWithPath: NSHomeDirectory())
                    .appendingPathComponent("Library")
                    .appendingPathComponent("Audio")
                    .appendingPathComponent("Presets")
            }

            /// Returns the user preset folder URLs for the given audio unit, creating the primary folder if needed.
            public static func getPresetsFolders(for audioUnit: AVAudioUnit) -> [URL]? {
                let url = AudioUnitPresets.Locations.userPresets

                guard let audioUnitName = audioUnit.auAudioUnit.audioUnitName else {
                    Log.debug("Couldn't get name of Audio Unit.")
                    return nil
                }

                guard let manufacturer = audioUnit.auAudioUnit.manufacturerName else {
                    Log.debug("Couldn't get name of Audio Unit manufacturer.")
                    return nil
                }

                let primaryURL = url.appendingPathComponent(manufacturer).appendingPathComponent(audioUnitName)

                var urls = [primaryURL]

                // FCP is/was saving presets under the fourcc rather than the manufacturer string. this is probably a bug
                let fourCC = audioUnit.auAudioUnit.componentDescription.componentManufacturer.fourCC

                urls.append(
                    url.appendingPathComponent(fourCC).appendingPathComponent(audioUnitName)
                )

                if !FileManager.default.fileExists(atPath: primaryURL.path) {
                    do {
                        try FileManager.default.createDirectory(
                            at: primaryURL,
                            withIntermediateDirectories: true,
                            attributes: nil
                        )
                    } catch {
                        Log.error("Unable to create preset folder at \(primaryURL.path):", error.localizedDescription)
                        return nil
                    }
                }

                return urls
            }

            /// Returns the URLs of all `.aupreset` files found in the user preset folders for the given audio unit.
            public static func getUserPresets(for audioUnit: AVAudioUnit) -> [URL]? {
                guard let presetsFolders = getPresetsFolders(for: audioUnit) else {
                    Log.error("Failed to get presets folder for", audioUnit.auAudioUnit.audioUnitName)
                    return nil
                }
                var out = [URL]()

                let options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsPackageDescendants]

                for folder in presetsFolders {
                    if let enumerator = FileManager().enumerator(
                        at: folder,
                        includingPropertiesForKeys: [],
                        options: options,
                        errorHandler: nil
                    ) {
                        while let url = enumerator.nextObject() as? URL {
                            if url.pathExtension == "aupreset" {
                                out.append(url)
                            }
                        }
                    }
                }

                return out
            }
        }
    #endif

    // MARK: Create Preset XML

    /// convenience used by for embedding full state in project XML
    public static func fullStateDocument(for avAudioUnit: AVAudioUnit) -> AEXMLDocument? {
        guard let state = avAudioUnit.auAudioUnit.fullState else { return nil }
        return try? PlistUtilities.dictionaryToPlist(dictionary: state)
    }

    /// Loads a preset from an XML element into the audio unit, returning the parsed full state dictionary.
    @discardableResult
    public static func loadPreset(for avAudioUnit: AVAudioUnit, element: AEXMLElement) async -> [String: Any]? {
        guard let fullState = try? PlistUtilities.plistToDictionary(element: element) else {
            return nil
        }

        await loadPreset(for: avAudioUnit, fullState: fullState)

        return fullState
    }

    /// Applies the given full state dictionary to the audio unit and notifies listeners of the change.
    /// Runs the fullState assignment at default priority to avoid priority inversion with AUAudioUnit internals.
    public static func loadPreset(for avAudioUnit: AVAudioUnit, fullState: [String: Any]) async {
        // Dispatch at default QoS to avoid priority inversion — AUAudioUnit.fullState
        // setter internally synchronises on a Default-QoS thread.
        nonisolated(unsafe) let state = fullState
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .default).async {
                avAudioUnit.auAudioUnit.fullState = state
                continuation.resume()
            }
        }

        let status = AudioUnitStateNotifier.notifyListeners(of: avAudioUnit.audioUnit)

        guard noErr == status else {
            Log.error("notifyAudioUnitListener returned error:", status.fourCC)
            return
        }
    }
}
