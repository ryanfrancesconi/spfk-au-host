// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

@preconcurrency import AudioToolbox
import AVFoundation
import SPFKBase
import SPFKUtils

/// Validates Audio Unit components using system APIs and optional external tools.
public class AudioUnitValidator {
    /// The outcome of validating a single Audio Unit, including the result status and optional output.
    public struct ValidationResult: Sendable {
        /// The validation result status (e.g., passed, failed, timed out).
        public var result: AudioComponentValidationResult
        /// Optional output text from the validation process.
        public var output: String?
        /// Why a component did not pass, for the user: the validator's error line, or the timeout.
        public var reason: String?

        public init(result: AudioComponentValidationResult, output: String? = nil, reason: String? = nil) {
            self.result = result
            self.output = output
            self.reason = reason
        }

        /// A result whose reason is read from the validator's output, or from `timeout` when it timed out.
        init(result: AudioComponentValidationResult, outputLines lines: [String], timeout: Duration) {
            let reason: String? = switch result {
            case .passed: nil
            case .timedOut: AudioUnitValidator.timeoutReason(timeout)
            default: AudioUnitValidator.reason(fromOutput: lines)
            }

            self.init(result: result, output: lines.isEmpty ? nil : lines.joined(separator: "\n"), reason: reason)
        }
    }

    /// The first `FATAL ERROR` or `ERROR:` line, trimmed, without an `ERROR: ` prefix.
    /// `WARNING:` lines are not reasons: passing plugins print them too.
    static func reason(fromOutput lines: [String]) -> String? {
        for line in lines {
            let line = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if line.hasPrefix("FATAL ERROR") {
                return line
            }

            if line.hasPrefix("ERROR:") {
                return String(line.dropFirst("ERROR:".count)).trimmingCharacters(in: .whitespaces)
            }
        }

        return nil
    }

    static func timeoutReason(_ timeout: Duration) -> String {
        "No response within \(timeout.components.seconds) seconds"
    }

    /// How long the system validator may take before it reports `.timedOut`.
    static let systemTimeout: Duration = .seconds(15)

    /// `force` makes the system validate again rather than replay the verdict it stored for this version.
    private static func validateParams(force: Bool) -> CFDictionary {
        var params: [String: Any] = [
            kAudioComponentValidationParameter_LoadOutOfProcess: 1,
            kAudioComponentValidationParameter_TimeOut: systemTimeout.components.seconds,
        ]

        if force {
            params[kAudioComponentValidationParameter_ForceValidation] = 1
        }

        return params as CFDictionary
    }

    // MARK: - Validate

    /// The system's verdict when it passes. Anything else is decided by `auval -v`, which the
    /// system API disagrees with itself against, and times out under load where `auval` does not.
    /// `forceExternal` skips the system's stored verdict and lets `auval` decide every component.
    public static func validate(component: AVAudioUnitComponent, forceExternal: Bool = false) async -> ValidationResult {
        #if os(macOS)
            await validate(
                component: component,
                forceExternal: forceExternal,
                executable: auval,
                system: { await validateWithResults(component: $0) },
                external: { await validateExternal(component: $0, executable: $1) }
            )
        #else
            await validateWithResults(component: component)
        #endif
    }

    #if os(macOS)
        /// The routing behind `validate(component:forceExternal:)`, with both tiers supplied.
        static func validate(
            component: AVAudioUnitComponent,
            forceExternal: Bool,
            executable: URL?,
            system: (AVAudioUnitComponent) async -> ValidationResult,
            external: (AVAudioUnitComponent, URL) async -> ValidationResult
        ) async -> ValidationResult {
            guard let executable else {
                return await system(component)
            }

            var systemResult: ValidationResult?

            if !forceExternal {
                let result = await system(component)
                guard result.result != .passed else { return result }
                systemResult = result
            }

            guard !Task.isCancelled else {
                return systemResult ?? ValidationResult(result: .unknown)
            }

            return await external(component, executable)
        }
    #endif

    /// Uses AudioComponentValidateWithResults, whose `TimeOut` parameter guarantees the callback
    /// fires within 15 seconds. Cancellation returns `.unknown` at once; the late callback is dropped.
    static func validateWithResults(component: AVAudioUnitComponent, force: Bool = false) async -> ValidationResult {
        let pending = PendingValidation()

        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                guard pending.store(continuation) else { return }

                let status = AudioComponentValidateWithResults(component.audioComponent, validateParams(force: force)) { result, details in
                    let lines = (details as NSDictionary)["Output"] as? [String] ?? []
                    pending.resume(returning: ValidationResult(result: result, outputLines: lines, timeout: systemTimeout))
                }

                if status != noErr {
                    Log.error("*AU AudioComponentValidateWithResults returned", status, "for", component.name)
                    pending.resume(returning: ValidationResult(result: .unknown))
                }
            }
        } onCancel: {
            pending.resume(returning: ValidationResult(result: .unknown))
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

        /// How long `auval -v` may run before it is ended and reported as `.timedOut`.
        static let externalTimeout: Duration = .seconds(15)

        /// Runs `auval -v` on the component. `executable` and `timeout` exist for tests.
        static func validateExternal(
            component: AVAudioUnitComponent,
            executable: URL? = auval,
            timeout: Duration = externalTimeout
        ) async -> ValidationResult {
            guard let cmd = executable else {
                return ValidationResult(result: .unknown)
            }

            let desc = component.audioComponentDescription

            let args = [
                "-v",
                desc.componentType.fourCC,
                desc.componentSubType.fourCC,
                desc.componentManufacturer.fourCC,
            ].compactMap(\.self)

            let output: ProcessOutput
            do {
                output = try await ProcessRunner.run(cmd, arguments: args, timeout: timeout)
            } catch {
                return ValidationResult(result: .failed, output: error.localizedDescription, reason: error.localizedDescription)
            }

            let text = output.stdout + output.stderr
            let result = output.timedOut ? .timedOut : parse(result: text)

            return ValidationResult(result: result, outputLines: text.components(separatedBy: .newlines), timeout: timeout)
        }

        static func parse(result: String) -> AudioComponentValidationResult {
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

/// A validation's continuation, resumed once by whichever of the callback and cancellation comes first.
private final class PendingValidation: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<AudioUnitValidator.ValidationResult, Never>?
    private var isFinished = false

    /// Returns false, having resumed `continuation` with `.unknown`, when cancellation came first.
    func store(_ continuation: CheckedContinuation<AudioUnitValidator.ValidationResult, Never>) -> Bool {
        let isFinished = lock.withLock {
            if !self.isFinished { self.continuation = continuation }
            return self.isFinished
        }

        if isFinished {
            continuation.resume(returning: AudioUnitValidator.ValidationResult(result: .unknown))
        }

        return !isFinished
    }

    func resume(returning result: AudioUnitValidator.ValidationResult) {
        let continuation = lock.withLock {
            isFinished = true
            defer { self.continuation = nil }
            return self.continuation
        }

        continuation?.resume(returning: result)
    }
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
