// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

import Foundation
import os
import Testing

@testable import SPFKAUHost

/// A call that never returns, standing in for an Apple AU call whose hosting process died. Released
/// at the end of each test so the parked task does not outlive it.
private final class StrandedCall: Sendable {
    private let parked = OSAllocatedUnfairLock<CheckedContinuation<Int, Never>?>(initialState: nil)

    func wait() async -> Int {
        await withCheckedContinuation { continuation in
            parked.withLock { $0 = continuation }
        }
    }

    func release() {
        parked.withLock { pending in
            let taken = pending
            pending = nil
            return taken
        }?.resume(returning: -1)
    }
}

private struct Abandoned: Error, Equatable {}

@Suite(.timeLimit(.minutes(1)))
struct AudioUnitHostingRaceTests {
    @Test func aCallThatNeverReturnsIsAbandoned() async throws {
        let call = StrandedCall()
        defer { call.release() }

        await #expect(throws: Abandoned.self) {
            try await firstToFinish {
                await call.wait()
            } or: {
                try await Task.sleep(for: .milliseconds(50))
                throw Abandoned()
            }
        }
    }

    @Test func aCallThatReturnsWinsWithoutWaitingOutTheLimit() async throws {
        let clock = ContinuousClock()
        let start = clock.now

        let value = try await firstToFinish {
            7
        } or: {
            try await Task.sleep(for: .seconds(30))
            throw Abandoned()
        }

        #expect(value == 7)
        #expect(clock.now - start < .seconds(5))
    }

    @Test func invalidatingTheObjectEndsTheWait() async {
        let object = UncheckedBox(value: NSObject())
        let waiting = Task { await waitForInvalidation(of: object.value) }

        await postUntilFinished(waiting, object: object.value)
    }

    @Test func invalidatingAnotherObjectDoesNotEndTheWait() async throws {
        let object = UncheckedBox(value: NSObject())
        let other = NSObject()
        let ended = OSAllocatedUnfairLock(initialState: false)

        let waiting = Task {
            await waitForInvalidation(of: object.value)
            ended.withLock { $0 = true }
        }

        try await Task.sleep(for: .milliseconds(100))
        NotificationCenter.default.post(name: .componentInstanceInvalidation, object: other)
        try await Task.sleep(for: .milliseconds(100))

        #expect(ended.withLock { $0 } == false)

        // Cancelling is the other way a wait ends.
        waiting.cancel()
        await waiting.value
        #expect(ended.withLock { $0 } == true)
    }

    /// The observer is added once the wait starts, so a single post can land before it: repeat
    /// until the wait reports it ended.
    private func postUntilFinished(_ waiting: Task<Void, Never>, object: NSObject) async {
        let done = OSAllocatedUnfairLock(initialState: false)
        let watcher = Task {
            await waiting.value
            done.withLock { $0 = true }
        }

        while !done.withLock({ $0 }) {
            NotificationCenter.default.post(name: .componentInstanceInvalidation, object: object)
            try? await Task.sleep(for: .milliseconds(20))
        }

        await watcher.value
    }
}
