// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

import AVFoundation
import Foundation

/// For the collection we only need the name and the audioComponentDescription. This struct
/// copies the rest of the Sendable properties from `AVAudioUnitComponent` and leaves out
/// the rest.
///
/// Note: Do not access `AVAudioUnitComponent.passesAUVal` in this. Non-description only fields are
/// deliberately left out. This is an info only struct.
///
public struct S_AVAudioUnitComponent: Equatable, Sendable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.audioComponentDescription.matches(rhs.audioComponentDescription)
    }

    /** @property name
     @abstract the name of an audio component
     */
    public let name: String

    /** @property audioComponentDescription
     @abstract description of the audio component that can be used in AudioComponent APIs.
     */
    public let audioComponentDescription: AudioComponentDescription

    /** @property typeName
     @abstract standard audio component types returned as strings
     */
    public let typeName: String

    /** @property localizedTypeName
     @abstract localized string of typeName for display
     */
    public let localizedTypeName: String

    /** @property manufacturerName
     @abstract the manufacturer name,
        extracted from the manufacturer key defined in Info.plist dictionary
     */
    public let manufacturerName: String

    /** @property version
     @abstract version number comprised of a hexadecimal number with major,
        minor,
        dot-release format: 0xMMMMmmDD
     */
    public let version: Int

    /** @property versionString
     @abstract version number as string
     */
    public let versionString: String

    /** @property availableArchitectures
     @abstract NSArray of NSNumbers each of which corresponds to one of the constants in Mach-O Architecture in NSBundle Class Reference
     */
    public let availableArchitectures: [NSNumber]

    /** @property sandboxSafe
     @abstract On OSX,
        YES if the AudioComponent can be loaded into a sandboxed process otherwise NO.
     On iOS,
        this is always YES.
     */
    public let isSandboxSafe: Bool

    /** @property hasMIDIInput
     @abstract YES if AudioComponent has midi input,
        otherwise NO
     */
    public let hasMIDIInput: Bool

    /** @property hasMIDIOutput
     @abstract YES if AudioComponent has midi output,
        otherwise NO
     */
    public let hasMIDIOutput: Bool
    //
    /** @property userTagNames
     @abstract User tags represent the tags from the current user.
     */

    public let userTagNames: [String]

    /** @property allTagNames
     @abstract represent the tags from the current user and the system tags defined by AudioComponent.
     */
    public let allTagNames: [String]

    /** @property iconURL
     @abstract A URL that will specify the location of an icon file that can be used when presenting UI
     for this audio component.
     */
    public let iconURL: URL?

    /** @property hasCustomView
     @abstract YES if the AudioComponent provides a custom view,
        otherwise NO
     */
    public let hasCustomView: Bool

    #if os(macOS)
        /// Creates a sendable snapshot by copying properties from the given `AVAudioUnitComponent`.
        public init(avAudioUnitComponent auc: AVAudioUnitComponent) {
            self = S_AVAudioUnitComponent(
                name: auc.name,
                audioComponentDescription: auc.audioComponentDescription,
                typeName: auc.typeName,
                localizedTypeName: auc.localizedTypeName,
                manufacturerName: auc.manufacturerName,
                version: auc.version,
                versionString: auc.versionString,
                availableArchitectures: auc.availableArchitectures,
                isSandboxSafe: auc.isSandboxSafe,
                hasMIDIInput: auc.hasMIDIInput,
                hasMIDIOutput: auc.hasMIDIOutput,
                userTagNames: auc.userTagNames,
                allTagNames: auc.allTagNames,
                iconURL: auc.iconURL,
                hasCustomView: auc.hasCustomView
            )
        }
    #else
        /// Creates a sendable snapshot by copying properties from the given `AVAudioUnitComponent`.
        public init(avAudioUnitComponent auc: AVAudioUnitComponent) {
            self = S_AVAudioUnitComponent(
                name: auc.name,
                audioComponentDescription: auc.audioComponentDescription,
                typeName: auc.typeName,
                localizedTypeName: auc.localizedTypeName,
                manufacturerName: auc.manufacturerName,
                version: auc.version,
                versionString: auc.versionString,
                availableArchitectures: [],
                isSandboxSafe: auc.isSandboxSafe,
                hasMIDIInput: auc.hasMIDIInput,
                hasMIDIOutput: auc.hasMIDIOutput,
                userTagNames: [],
                allTagNames: auc.allTagNames,
                iconURL: nil,
                hasCustomView: false
            )
        }
    #endif

    /// Memberwise initializer for all audio component properties.
    public init(
        name: String,
        audioComponentDescription: AudioComponentDescription,
        typeName: String,
        localizedTypeName: String,
        manufacturerName: String,
        version: Int,
        versionString: String,
        availableArchitectures: [NSNumber],
        isSandboxSafe: Bool,
        hasMIDIInput: Bool,
        hasMIDIOutput: Bool,
        userTagNames: [String],
        allTagNames: [String],
        iconURL: URL?,
        hasCustomView: Bool
    ) {
        self.name = name
        self.audioComponentDescription = audioComponentDescription
        self.typeName = typeName
        self.localizedTypeName = localizedTypeName
        self.manufacturerName = manufacturerName
        self.version = version
        self.versionString = versionString
        self.availableArchitectures = availableArchitectures
        self.isSandboxSafe = isSandboxSafe
        self.hasMIDIInput = hasMIDIInput
        self.hasMIDIOutput = hasMIDIOutput
        self.userTagNames = userTagNames
        self.allTagNames = allTagNames
        self.iconURL = iconURL
        self.hasCustomView = hasCustomView
    }
}
