// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

import AEXML
import AudioToolbox
@preconcurrency import AVFoundation
import Foundation
import SPFKBase
import SPFKUtils

#if os(macOS)

    extension AudioUnitPresets {
        /// (Legacy) file system locations for user audio unit presets - Technically superseeded by auAudioUnit.userPresets added in 10.15
        public enum Locations {
            /// User's home directory presets folder
            static var userPresets: URL {
                URL(fileURLWithPath: NSHomeDirectory())
                    .appendingPathComponent("Library")
                    .appendingPathComponent("Audio")
                    .appendingPathComponent("Presets")
            }

            /// Returns the user preset folder URLs for the given audio unit, creating the primary folder if needed.
            public static func presetsFolder(for audioUnit: AVAudioUnit) -> [URL]? {
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

                // FCP is/was saving presets under the fourcc rather than the manufacturer string. this is probably a bug?
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
            public static func userPresets(for audioUnit: AVAudioUnit) -> [URL]? {
                guard let presetsFolders = presetsFolder(for: audioUnit) else {
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
    }

#endif
