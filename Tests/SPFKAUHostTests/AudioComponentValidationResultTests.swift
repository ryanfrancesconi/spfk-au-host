import AudioToolbox
import Foundation
import Testing

@testable import SPFKAUHost

struct AudioComponentValidationResultDescriptionTests {
    // MARK: - init from description round-trip

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
