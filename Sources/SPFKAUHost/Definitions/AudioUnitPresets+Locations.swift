// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

import Foundation

#if os(macOS)

    extension AudioUnitPresets {
        /// File system locations for audio unit presets.
        /// Previously presets were stored in the app sandbox; they now use the standard system location shared by all macOS audio applications.
        public enum Locations {
            /// Standard user preset directory: `~/Library/Audio/Presets/`
            public static var userPresets: URL {
                URL(fileURLWithPath: NSHomeDirectory())
                    .appendingPathComponent("Library")
                    .appendingPathComponent("Audio")
                    .appendingPathComponent("Presets")
            }
        }
    }

#endif
