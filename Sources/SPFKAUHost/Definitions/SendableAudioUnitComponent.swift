// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

import AVFoundation
import Foundation

/// For the collection we mostly need the name and the audioComponentDescription. This struct
/// copies the rest of the Sendable properties from `AVAudioUnitComponent` and leaves out
/// the rest.
public struct SendableAudioUnitComponent: Equatable, Sendable {
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
         @abstract the manufacturer name, extracted from the manufacturer key defined in Info.plist dictionary
     */
    public let manufacturerName: String

    /** @property version
         @abstract version number comprised of a hexadecimal number with major, minor, dot-release format: 0xMMMMmmDD
     */
    public let version: Int

    /** @property versionString
         @abstract version number as string
     */
    public let versionString: String

    public let availableArchitectures: [NSNumber]

    /** @property sandboxSafe
         @abstract On OSX, YES if the AudioComponent can be loaded into a sandboxed process otherwise NO.
                   On iOS, this is always YES.
     */
    public let isSandboxSafe: Bool

    /** @property hasMIDIInput
         @abstract YES if AudioComponent has midi input, otherwise NO
     */
    public let hasMIDIInput: Bool

    /** @property hasMIDIOutput
         @abstract YES if AudioComponent has midi output, otherwise NO
     */
    public let hasMIDIOutput: Bool

    /** @property userTagNames
         @abstract User tags represent the tags from the current user.
     */

    public let userTagNames: [String]

    /** @property allTagNames
         @abstract represent the tags from the current user and the system tags defined by AudioComponent.
     */
    public let allTagNames: [String]

    public let iconURL: URL?

    public let cgImage: CGImage?

    public let passesAUVal: Bool

    /** @property hasCustomView
         @abstract YES if the AudioComponent provides custom view, otherwise NO
     */
    public let hasCustomView: Bool

    public init(avAudioUnitCompoment auc: AVAudioUnitComponent) {
        name = auc.name
        audioComponentDescription = auc.audioComponentDescription
        typeName = auc.typeName
        localizedTypeName = auc.localizedTypeName
        manufacturerName = auc.manufacturerName
        version = auc.version
        versionString = auc.versionString
        availableArchitectures = auc.availableArchitectures
        isSandboxSafe = auc.isSandboxSafe
        hasMIDIInput = auc.hasMIDIInput
        hasMIDIOutput = auc.hasMIDIOutput
        userTagNames = auc.userTagNames
        allTagNames = auc.allTagNames
        iconURL = auc.iconURL
        cgImage = auc.icon?.cgImage
        passesAUVal = auc.passesAUVal
        hasCustomView = auc.hasCustomView
    }

    public init(
        name: String, audioComponentDescription: AudioComponentDescription, typeName: String, localizedTypeName: String,
        manufacturerName: String, version: Int, versionString: String, availableArchitectures: [NSNumber],
        isSandboxSafe: Bool, hasMIDIInput: Bool, hasMIDIOutput: Bool, userTagNames: [String], allTagNames: [String],
        iconURL: URL?, cgImage: CGImage?, passesAUVal: Bool, hasCustomView: Bool
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
        self.cgImage = cgImage
        self.passesAUVal = passesAUVal
        self.hasCustomView = hasCustomView
    }
}
