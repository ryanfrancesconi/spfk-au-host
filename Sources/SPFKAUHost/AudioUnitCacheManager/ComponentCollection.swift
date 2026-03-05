// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

import SPFKAudioBase
import SPFKAUHostC
import SPFKUtils

/// A collection of Audio Unit component validation results with filtering and update capabilities.
public struct ComponentCollection: Sendable {
    /// Whether this collection contains no validation results.
    public var isEmpty: Bool {
        validationResults.isEmpty
    }

    /// All validation results in this collection.
    public var validationResults: [ComponentValidationResult]

    /// Validation results that passed and are format-compatible, sorted by description.
    public var passedEffects: [ComponentValidationResult] {
        validationResults.filter {
            $0.validation.result == .passed && $0.isFormatCompatible

        }.sorted { lhs, rhs in
            lhs.description < rhs.description
        }
    }

    /// Validation results for components that are not format-compatible, sorted by description.
    public var unavailableEffects: [ComponentValidationResult] {
        validationResults.filter {
            !$0.isFormatCompatible
        }.sorted { lhs, rhs in
            lhs.description < rhs.description
        }
    }

    /// Validation results for components that did not pass validation, sorted by description.
    public var failedEffects: [ComponentValidationResult] {
        validationResults.filter {
            $0.validation.result != .passed
        }.sorted { lhs, rhs in
            lhs.description < rhs.description
        }
    }

    /// A formatted summary of validation results grouped by passed, failed, and unavailable components.
    public var validationDescription: String {
        func flatten(collection: [ComponentValidationResult], title: String) -> String {
            var text = ""
            text += "\(title)\n\n"

            text += collection.map(\.description).sorted().joined(separator: "\n")
            return text
        }

        var text = HardwareInfo.description

        let passedEffects = passedEffects
        let failedEffects = failedEffects
        let unavailableEffects = unavailableEffects

        if passedEffects.isNotEmpty {
            let title = "\(passedEffects.count) Audio Unit\(passedEffects.pluralString) \(passedEffects.count == 1 ? "is" : "are") compatible:"
            text += flatten(collection: passedEffects, title: title)
            text += "\n\n"
        }

        if failedEffects.isNotEmpty {
            let unableToOpen = failedEffects.filter { $0.validation.result != .failed }
            let failed = failedEffects.filter { $0.validation.result == .failed }

            if failed.isNotEmpty {
                text += flatten(collection: failed, title: "These Audio Units didn't pass validation:")
                text += "\n\n"
            }

            if unableToOpen.isNotEmpty {
                text += flatten(collection: unableToOpen, title: "Unable to open:")
                text += "\n\n"
            }
        }

        if unavailableEffects.isNotEmpty {
            let incompatibleEffects = unavailableEffects.filter(\.supportsStereo)

            if incompatibleEffects.isNotEmpty {
                text += flatten(collection: incompatibleEffects, title: "These Audio Units aren't supported:")
                text += "\n\n"
            }

            let monoEffects = unavailableEffects.filter { $0.supportsMono && !$0.supportsStereo }

            if monoEffects.isNotEmpty {
                text += flatten(collection: monoEffects, title: "Currently only supporting stereo Audio Units. These are mono:")
                text += "\n\n"
            }
        }

        return text
    }

    /// Sorted list of unique Audio Unit type names present in the collection.
    public var effectTypes: [String] {
        validationResults.compactMap {
            $0.component?.typeName
        }.removingDuplicatesRandomOrdering().sorted()
    }

    /// Creates a collection from the given validation results, filtering out Spongefork components.
    public init(results: [ComponentValidationResult]) {
        validationResults = results.filter {
            $0.audioComponentDescription.componentManufacturer !=
                kAudioUnitManufacturer_Spongefork
        }
    }

    /// Updates the enabled state for all results matching the given audio component description.
    public mutating func update(audioComponentDescription: AudioComponentDescription, isEnabled: Bool) {
        for i in 0 ..< validationResults.count
            where validationResults[i].audioComponentDescription.matches(audioComponentDescription)
        {
            //
            validationResults[i].isEnabled = isEnabled
        }
    }

    /// Updates the validation result for all entries matching the given result's audio component description.
    public mutating func update(result: ComponentValidationResult) {
        for i in 0 ..< validationResults.count
            where validationResults[i].audioComponentDescription.matches(result.audioComponentDescription)
        {
            //
            validationResults[i].validation = result.validation
        }
    }

    /// Restores enabled states from another collection by matching audio component descriptions.
    public mutating func updateEnabled(from collection: ComponentCollection) {
        for item in collection.validationResults {
            update(audioComponentDescription: item.audioComponentDescription, isEnabled: item.isEnabled)
        }
    }
}
