// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

@preconcurrency import AVFoundation
import SPFKBase

/// The result of validating a single Audio Unit component, including its metadata and validation status.
public struct ComponentValidationResult: Sendable {
    /// The audio component description identifying this Audio Unit.
    public let audioComponentDescription: AudioComponentDescription
    /// The resolved `AVAudioUnitComponent`, or nil if unavailable on the system.
    public let component: AVAudioUnitComponent?
    /// The display name of the Audio Unit.
    public let name: String
    /// The type name of the Audio Unit (e.g., effect, instrument).
    public let typeName: String
    /// The manufacturer name of the Audio Unit.
    public let manufacturerName: String
    /// The version string of the Audio Unit.
    public let versionString: String

    /// The validation result indicating whether this component passed validation.
    public var validation: AudioUnitValidator.ValidationResult
    /// Whether this component is enabled by the user.
    public var isEnabled: Bool

    /// Whether this component is an effect or music device and supports stereo.
    public var isFormatCompatible: Bool {
        (audioComponentDescription.isEffect || audioComponentDescription.isMusicDevice)
            && component?.supportsStereo == true
    }

    /// Whether the underlying component supports mono channel layout.
    public var supportsMono: Bool {
        component?.supportsMono == true
    }

    /// Whether the underlying component supports stereo channel layout.
    public var supportsStereo: Bool {
        component?.supportsStereo == true
    }

    /// A textual description including the component's manufacturer, name, type, and validation command.
    public var description: String {
        if let component {
            "\(component.manufacturerName): \(component.name) (\(component.typeName)), "
                + "More info: \(component.audioComponentDescription.validationCommand)"
        } else {
            audioComponentDescription.validationCommand
        }
    }

    /// Creates a validation result from a resolved `AVAudioUnitComponent`.
    public init(
        audioComponentDescription: AudioComponentDescription,
        component: AVAudioUnitComponent,
        validation: AudioUnitValidator.ValidationResult,
        isEnabled: Bool = true
    ) {
        self.audioComponentDescription = audioComponentDescription
        self.component = component
        self.validation = validation
        self.isEnabled = isEnabled

        name = component.name
        typeName = component.localizedTypeName
        manufacturerName = component.manufacturerName
        versionString = component.versionString
    }

    /// Creates a validation result with explicit metadata when no `AVAudioUnitComponent` is available.
    public init(
        audioComponentDescription: AudioComponentDescription,
        validation: AudioUnitValidator.ValidationResult,
        isEnabled: Bool = true,
        name: String,
        typeName: String,
        manufacturerName: String,
        versionString: String,
    ) {
        component = nil
        self.audioComponentDescription = audioComponentDescription
        self.validation = validation
        self.isEnabled = isEnabled
        self.name = name
        self.typeName = typeName
        self.manufacturerName = manufacturerName
        self.versionString = versionString
    }
}
