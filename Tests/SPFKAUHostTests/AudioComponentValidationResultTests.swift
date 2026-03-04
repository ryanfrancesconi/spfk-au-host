import AudioToolbox
import Foundation
import Testing

@testable import SPFKAUHost

struct AudioComponentValidationResultDescriptionTests {
    @Test func unknownDescription() {
        #expect(AudioComponentValidationResult.unknown.description == "Unknown")
    }

    @Test func passedDescription() {
        #expect(AudioComponentValidationResult.passed.description == "Passed")
    }

    @Test func failedDescription() {
        #expect(AudioComponentValidationResult.failed.description == "Failed")
    }

    @Test func timedOutDescription() {
        #expect(AudioComponentValidationResult.timedOut.description == "Timed out")
    }

    @Test func unauthorizedErrorOpenDescription() {
        #expect(AudioComponentValidationResult.unauthorizedError_Open.description == "Unable to open")
    }

    @Test func unauthorizedErrorInitDescription() {
        #expect(AudioComponentValidationResult.unauthorizedError_Init.description == "Unable to initialize")
    }

    // MARK: - init from description round-trip

    @Test func initFromDescriptionUnknown() {
        let result = AudioComponentValidationResult(description: "Unknown")
        #expect(result == .unknown)
    }

    @Test func initFromDescriptionPassed() {
        let result = AudioComponentValidationResult(description: "Passed")
        #expect(result == .passed)
    }

    @Test func initFromDescriptionFailed() {
        let result = AudioComponentValidationResult(description: "Failed")
        #expect(result == .failed)
    }

    @Test func initFromDescriptionTimedOut() {
        let result = AudioComponentValidationResult(description: "Timed out")
        #expect(result == .timedOut)
    }

    @Test func initFromDescriptionUnableToOpen() {
        let result = AudioComponentValidationResult(description: "Unable to open")
        #expect(result == .unauthorizedError_Open)
    }

    @Test func initFromDescriptionUnableToInitialize() {
        let result = AudioComponentValidationResult(description: "Unable to initialize")
        #expect(result == .unauthorizedError_Init)
    }

    @Test func initFromDescriptionInvalid() {
        let result = AudioComponentValidationResult(description: "InvalidValue")
        #expect(result == nil)
    }

    @Test func roundTripAllCases() {
        let cases: [AudioComponentValidationResult] = [
            .unknown, .passed, .failed, .timedOut,
            .unauthorizedError_Open, .unauthorizedError_Init,
        ]

        for original in cases {
            let roundTripped = AudioComponentValidationResult(description: original.description)
            #expect(roundTripped == original)
        }
    }
}
