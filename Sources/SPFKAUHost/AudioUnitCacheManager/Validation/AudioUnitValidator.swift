// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

@preconcurrency import AudioToolbox
import AVFoundation
import SPFKUtils

/// Validates Audio Unit components using system APIs and optional external tools.
public class AudioUnitValidator {
    /// The outcome of validating a single Audio Unit, including the result status and optional output.
    public struct ValidationResult: Sendable {
        /// The validation result status (e.g., passed, failed, timed out).
        public var result: AudioComponentValidationResult
        /// Optional output text from the validation process.
        public var output: String?
    }

    private static var validateParams: CFDictionary {
        [
            kAudioComponentValidationParameter_LoadOutOfProcess: 1,
            kAudioComponentValidationParameter_TimeOut: 15,
        ] as CFDictionary
    }

    // MARK: - System Cache

    /// Checks the system's cached validation result for a component.
    /// Returns the cached result if available, nil otherwise.
    static func cachedSystemValidationResult(
        for component: AVAudioUnitComponent
    ) -> AudioComponentValidationResult? {
        var configInfo: Unmanaged<CFDictionary>?

        let status = AudioComponentCopyConfigurationInfo(
            component.audioComponent,
            &configInfo
        )

        guard status == noErr,
              let dict = configInfo?.takeRetainedValue() as? [String: Any],
              let rawValue = dict[kAudioComponentConfigurationInfo_ValidationResult as String] as? UInt32
        else {
            return nil
        }

        return AudioComponentValidationResult(rawValue: rawValue)
    }

    // MARK: - Validate

    /// Validates the given Audio Unit component, falling back to external validation on macOS if needed.
    public static func validate(component: AVAudioUnitComponent) async -> ValidationResult {
        // Fast path: trust the system's cached validation result if it says "passed"
        if let systemResult = cachedSystemValidationResult(for: component),
           systemResult == .passed
        {
            return ValidationResult(result: .passed)
        }

        // note component.passesAUVal causes some AUs to hang indefinitely here

        let result: ValidationResult =
            if #available(macOS 13.0, iOS 16.0, *) {
                await validateWithResults(component: component)

            } else {
                await validateLegacy(component: component)
            }

        if result.result == .passed {
            return ValidationResult(result: .passed)
        }

        #if os(macOS)
            return await validateExternal(component: component)
        #else
            return result
        #endif
    }

    /// Wraps the synchronous AudioComponentValidate C API off the cooperative thread pool
    /// using a GCD dispatch to avoid blocking Swift Concurrency threads.
    static func validateLegacy(component: AVAudioUnitComponent) async -> ValidationResult {
        nonisolated(unsafe) let audioComponent = component.audioComponent
        let params = validateParams

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var result: AudioComponentValidationResult = .unknown

                let status = AudioComponentValidate(audioComponent, params, &result)

                guard status == noErr else {
                    Log.error("*AU AudioComponentValidate error", status.fourCC)
                    continuation.resume(returning: ValidationResult(result: .failed, output: nil))
                    return
                }

                continuation.resume(returning: ValidationResult(result: result))
            }
        }
    }

    /// Uses the modern AudioComponentValidateWithResults API with a checked continuation
    /// instead of a DispatchSemaphore. The timeout is handled by kAudioComponentValidationParameter_TimeOut
    /// in the params dictionary, which guarantees the callback fires.
    @available(macOS 13.0, iOS 16.0, *)
    static func validateWithResults(component: AVAudioUnitComponent) async -> ValidationResult {
        await withCheckedContinuation { continuation in
            AudioComponentValidateWithResults(component.audioComponent, validateParams) { result, _ in
                continuation.resume(returning: ValidationResult(result: result))
            }
        }
    }

    #if os(macOS)
        /// The URL to the `auvaltool` or `auval` command-line utility, or nil if neither is found.
        public static var auval: URL? {
            let cmd1 = URL(fileURLWithPath: "/usr/bin/auvaltool")

            if cmd1.exists {
                return cmd1
            }

            let cmd2 = URL(fileURLWithPath: "/usr/bin/auval")

            if cmd2.exists {
                return cmd2
            }

            // neither tool found
            return nil
        }

        /// Wraps ProcessHandler.run() off the cooperative thread pool
        /// using a GCD dispatch to avoid blocking Swift Concurrency threads.
        static func validateExternal(component: AVAudioUnitComponent) async -> ValidationResult {
            guard let cmd = auval else {
                return ValidationResult(result: .unknown)
            }

            let desc = component.audioComponentDescription

            let args = [
                "-v",
                desc.componentType.fourCC,
                desc.componentSubType.fourCC,
                desc.componentManufacturer.fourCC,
            ].compactMap(\.self)

            let name = component.name

            Log.default(
                "*AU validateExternal \(name):", cmd.lastPathComponent + " " + args.joined(separator: " ")
            )

            return await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    let process = ProcessHandler(url: cmd, args: args, qos: .default)

                    do {
                        let out = try process.run()

                        let result = parse(result: out)

                        if result != .passed {
                            Log.error("*AU validateExternal", name, "result:", result.description)
                        } else {
                            Log.default("*AU validateExternal", name, "result:", result.description)
                        }

                        continuation.resume(returning: ValidationResult(
                            result: result,
                            output: out,
                        ))

                    } catch {
                        continuation.resume(returning: ValidationResult(result: .failed, output: error.localizedDescription))
                    }
                }
            }
        }

        private static func parse(result: String) -> AudioComponentValidationResult {
            if result.contains("AU VALIDATION SUCCEEDED") {
                .passed

            } else if result.contains("FATAL ERROR: OpenAComponent") {
                .unauthorizedError_Open

            } else if result.contains("FATAL ERROR: Initialize") {
                .unauthorizedError_Init

            } else {
                .failed
            }
        }
    #endif
}

extension AudioComponentValidationResult {
    /**
     case unknown = 0
     case passed = 1
     case failed = 2
     case timedOut = 3
     case unauthorizedError_Open = 4
     case unauthorizedError_Init = 5
     */
    public var description: String {
        switch self {
        case .unknown:
            return "Unknown"
        case .passed:
            return "Passed"
        case .failed:
            return "Failed"
        case .timedOut:
            return "Timed out"
        case .unauthorizedError_Open:
            return "Unable to open"
        case .unauthorizedError_Init:
            return "Unable to initialize"
        @unknown default:
            return "Unknown"
        }
    }

    /// Creates a validation result from its string description, or returns nil if unrecognized.
    public init?(description: String) {
        switch description {
        case "Unknown":
            self = .unknown
        case "Passed":
            self = .passed
        case "Failed":
            self = .failed
        case "Timed out":
            self = .timedOut
        case "Unable to open":
            self = .unauthorizedError_Open
        case "Unable to initialize":
            self = .unauthorizedError_Init
        default:
            return nil
        }
    }
}
