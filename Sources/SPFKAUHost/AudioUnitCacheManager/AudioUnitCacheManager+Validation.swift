// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

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

    /// All the components that this framework can support. Spongefork's own units are registered
    /// in process and are internal, so they are never offered, validated or cached.
    public static var compatibleComponents: [AVAudioUnitComponent] {
        let components = AVAudioUnitComponentManager
            .shared()
            .components(matching: predicate)
            .filter { $0.audioComponentDescription.componentManufacturer != kAudioUnitManufacturer_Spongefork }

        return components.removingDuplicatesRandomOrdering()
    }

    /// Returns whether the given component description requires validation (excludes Apple components).
    /// Spongefork components auto-pass so that `auval` warnings from the lowercase manufacturer code don't surface.
    public static func shouldValidate(audioComponentDescription: AudioComponentDescription) -> Bool {
        let manufacturer = audioComponentDescription.componentManufacturer

        return manufacturer != kAudioUnitManufacturer_Apple &&
            manufacturer != kAudioUnitManufacturer_Spongefork
    }

    /// Validates the given components (or all compatible components if nil) and returns their validation results.
    /// Uses a TaskGroup with a sliding window of concurrent validations for throughput. Runs in the
    /// caller's task, so cancelling a scan cancels the validations in flight.
    public func validate(
        components: [AVAudioUnitComponent]? = nil,
        forceExternal: Bool = false
    ) async throws -> [ComponentValidationResult] {
        let maxConcurrency = 4

        let resolvedComponents = components ?? cachedCompatibleComponents()
        let validator = componentValidator
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
                    await validator(component, forceExternal)
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
                        await validator(component, forceExternal)
                    }
                    nextIndex += 1
                }
            }

            return results.sorted { $0.manufacturerName < $1.manufacturerName }
        }
    }

    static func validate(component: AVAudioUnitComponent, forceExternal: Bool) async -> ComponentValidationResult {
        guard shouldValidate(audioComponentDescription: component.audioComponentDescription) else {
            return ComponentValidationResult(
                audioComponentDescription: component.audioComponentDescription,
                component: component,
                validation: AudioUnitValidator.ValidationResult(result: .passed)
            )
        }

        let validationResult = await AudioUnitValidator.validate(component: component, forceExternal: forceExternal)

        if validationResult.result != .passed {
            Log.error("*AU validation failed for", component.resolvedName, ". More info run in terminal:", component.audioComponentDescription.validationCommand)
        }

        return ComponentValidationResult(
            audioComponentDescription: component.audioComponentDescription,
            component: component,
            validation: validationResult
        )
    }
}
