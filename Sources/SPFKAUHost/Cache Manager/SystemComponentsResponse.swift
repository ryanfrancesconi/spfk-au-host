// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

import Foundation

public struct SystemComponentsResponse: Sendable {
    public let results: [ComponentValidationResult]

    public init(results: [ComponentValidationResult] = []) {
        self.results = results
    }
}
