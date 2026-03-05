// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

import Foundation

/// Contains the validation results returned from a system component scan.
public struct SystemComponentsResponse: Sendable {
    /// The array of component validation results from the scan.
    public let results: [ComponentValidationResult]

    /// Creates a response with the given validation results.
    public init(results: [ComponentValidationResult] = []) {
        self.results = results
    }
}
