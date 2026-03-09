// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

import AEXML
import AudioToolbox
@preconcurrency import AVFoundation
import SPFKAudioBase
import SPFKBase
import SwiftExtensions

extension AudioUnitCacheManager {
    /// The total number of registered audio components on the system.
    public static var audioComponentCount: Int {
        var desc = AudioComponentDescription.wildcard
        let count = AudioComponentCount(&desc)
        return count.int
    }

    private static var predicate: NSPredicate {
        let predicate1 = NSPredicate(
            format: "typeName == '\(AVAudioUnitTypeEffect)'", argumentArray: nil
        )

        let predicate2 = NSPredicate(
            format: "typeName == '\(AVAudioUnitTypeMusicEffect)'", argumentArray: nil
        )

        let predicate3 = NSPredicate(
            format: "typeName == '\(AVAudioUnitTypeMusicDevice)'", argumentArray: nil
        )

        let predicate4 = NSPredicate(
            format: "typeName == '\(AVAudioUnitTypeGenerator)'", argumentArray: nil
        )

        return NSCompoundPredicate(
            orPredicateWithSubpredicates: [
                predicate1, predicate2, predicate3, predicate4,
            ]
        )
    }

    /// All the components that this framework can support
    public static var compatibleComponents: [AVAudioUnitComponent] {
        Log.debug("*AU Requesting compatibleComponents from system...")

        let components = AVAudioUnitComponentManager
            .shared()
            .components(matching: predicate)
            .filter {
                $0.audioComponentDescription.componentManufacturer !=
                    kAudioUnitManufacturer_Spongefork
            }

        return components.removingDuplicatesRandomOrdering()
    }

    /// Returns whether the given component description requires validation (excludes Apple and Spongefork components).
    public static func shouldValidate(audioComponentDescription: AudioComponentDescription) -> Bool {
        let manufacturer = audioComponentDescription.componentManufacturer

        return manufacturer != kAudioUnitManufacturer_Apple &&
            manufacturer != kAudioUnitManufacturer_Spongefork
    }

    /// Validates the given components (or all compatible components if nil) and returns their validation results.
    /// Uses a TaskGroup with a sliding window of concurrent validations for throughput.
    public func validate(components: [AVAudioUnitComponent]? = nil) async throws -> [ComponentValidationResult] {
        let maxConcurrency = 4

        // Snapshot actor state before entering the unstructured Task
        let resolvedComponents = components ?? cachedCompatibleComponents()
        let allowedDescs = allowedComponentDescriptions

        scanTask = Task<[ComponentValidationResult], Error>(priority: .high) {
            let count = resolvedComponents.count

            return try await withThrowingTaskGroup(
                of: ComponentValidationResult.self,
                returning: [ComponentValidationResult].self
            ) { taskGroup in
                try Task.checkCancellation()

                // Seed the initial batch
                let initialBatch = min(maxConcurrency, count)

                for i in 0 ..< initialBatch {
                    let component = resolvedComponents[i]
                    taskGroup.addTask {
                        await Self.validate(component: component, allowedDescriptions: allowedDescs)
                    }
                }

                var results = [ComponentValidationResult]()
                results.reserveCapacity(count)
                var nextIndex = initialBatch
                var completedCount = 0

                // As each task completes, report progress and enqueue the next
                for try await result in taskGroup {
                    try Task.checkCancellation()

                    results.append(result)
                    completedCount += 1

                    await self.send(event: .validating(
                        name: result.name,
                        completed: completedCount,
                        count: count
                    ))

                    if nextIndex < count {
                        let component = resolvedComponents[nextIndex]
                        taskGroup.addTask {
                            await Self.validate(component: component, allowedDescriptions: allowedDescs)
                        }
                        nextIndex += 1
                    }
                }

                return results.sorted { $0.manufacturerName < $1.manufacturerName }
            }
        }

        defer { scanTask = nil }
        return try await scanTask?.value ?? []
    }

    private static func validate(
        component: AVAudioUnitComponent,
        allowedDescriptions: [AudioComponentDescription]
    ) async -> ComponentValidationResult {
        guard shouldValidate(audioComponentDescription: component.audioComponentDescription) else {
            Log.debug("* Skipping", component.name)

            return ComponentValidationResult(
                audioComponentDescription: component.audioComponentDescription,
                component: component,
                validation: AudioUnitValidator.ValidationResult(result: .passed)
            )
        }

        let audioComponentDescription = component.audioComponentDescription

        let validationResult = await AudioUnitValidator.validate(component: component)

        if validationResult.result != .passed {
            Log.error("*AU validation failed for", component.resolvedName, ". More info run in terminal:", component.audioComponentDescription.validationCommand)
        }

        // HACK: Some special cases that might not be effects or music device specified
        if allowedDescriptions.contains(where: {
            audioComponentDescription.matches($0)
        }) {
            return ComponentValidationResult(
                audioComponentDescription: component.audioComponentDescription,
                component: component,
                validation: AudioUnitValidator.ValidationResult(result: .passed)
            )
        }

        return ComponentValidationResult(
            audioComponentDescription: component.audioComponentDescription,
            component: component,
            validation: validationResult
        )
    }
}
