// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

import AudioToolbox
import CoreAudioKit
import Foundation
import os
import SPFKBase

/// Returns what `operation` produces, unless `abandon` finishes first.
///
/// For Apple's async AU calls, which never return when the AU's hosting process dies mid-call. A task
/// group cannot race one, since it waits for every child, so the loser is cancelled and left behind.
func firstToFinish<T>(
    _ operation: @escaping @Sendable () async throws -> T,
    or abandon: @escaping @Sendable () async throws -> T
) async throws -> T {
    let boxed: UncheckedBox<T> = try await withCheckedThrowingContinuation { continuation in
        let gate = ResumeOnce(continuation)

        gate.hold([operation, abandon].map { body in
            Task {
                do {
                    try await gate.resume(with: .success(UncheckedBox(value: body())))
                } catch {
                    gate.resume(with: .failure(error))
                }
            }
        })
    }

    return boxed.value
}

/// Returns when `object` is reported invalidated -- its hosting process died or dropped the
/// connection -- or when the calling task is cancelled.
func waitForInvalidation(of object: AnyObject) async {
    let wait = InvalidationWait(target: ObjectIdentifier(object))

    await withTaskCancellationHandler {
        await withCheckedContinuation { wait.start($0) }
    } onCancel: {
        wait.finish()
    }
}

/// Carries a value from the task that made it to the one awaiting it, and is never shared.
struct UncheckedBox<T>: @unchecked Sendable {
    let value: T
}

// MARK: -

/// Resumes a continuation once, from whichever task gets there first, and cancels the rest.
private final class ResumeOnce<T>: Sendable {
    private struct State: @unchecked Sendable {
        var continuation: CheckedContinuation<UncheckedBox<T>, Error>?
        var tasks: [Task<Void, Never>] = []
    }

    private let state: OSAllocatedUnfairLock<State>

    init(_ continuation: CheckedContinuation<UncheckedBox<T>, Error>) {
        state = OSAllocatedUnfairLock(initialState: State(continuation: continuation))
    }

    func hold(_ tasks: [Task<Void, Never>]) {
        let isResumed = state.withLock { state in
            if state.continuation != nil { state.tasks = tasks }
            return state.continuation == nil
        }

        if isResumed { tasks.forEach { $0.cancel() } }
    }

    func resume(with result: Result<UncheckedBox<T>, Error>) {
        let (continuation, tasks) = state.withLock { state in
            defer { state = State(continuation: nil) }
            return (state.continuation, state.tasks)
        }

        continuation?.resume(with: result)
        tasks.forEach { $0.cancel() }
    }
}

/// One wait on `componentInstanceInvalidation` for one object. Either side may finish first:
/// the notification, or cancellation of the waiting task.
private final class InvalidationWait: Sendable {
    private struct State: @unchecked Sendable {
        var continuation: CheckedContinuation<Void, Never>?
        var observer: NSObjectProtocol?
        var isFinished = false
    }

    private let target: ObjectIdentifier
    private let state = OSAllocatedUnfairLock(initialState: State())

    init(target: ObjectIdentifier) {
        self.target = target
    }

    func start(_ continuation: CheckedContinuation<Void, Never>) {
        let isFinished = state.withLock { state in
            if !state.isFinished { state.continuation = continuation }
            return state.isFinished
        }

        guard !isFinished else {
            continuation.resume()
            return
        }

        let observer = NotificationCenter.default.addObserver(
            forName: .componentInstanceInvalidation, object: nil, queue: nil
        ) { [weak self, target] notification in
            guard let invalidated = notification.object as AnyObject?,
                  ObjectIdentifier(invalidated) == target
            else { return }

            self?.finish()
        }

        let finishedMeanwhile = state.withLockUnchecked { state in
            if !state.isFinished { state.observer = observer }
            return state.isFinished
        }

        if finishedMeanwhile { NotificationCenter.default.removeObserver(observer) }
    }

    func finish() {
        let (continuation, observer) = state.withLockUnchecked { state in
            guard !state.isFinished else { return (CheckedContinuation<Void, Never>?.none, NSObjectProtocol?.none) }
            defer { state = State(isFinished: true) }
            return (state.continuation, state.observer)
        }

        if let observer { NotificationCenter.default.removeObserver(observer) }
        continuation?.resume()
    }
}

/// An AU call abandoned because its hosting process stopped answering.
public enum AudioUnitHostingError: Error, Equatable {
    case instantiationTimedOut
}

#if os(macOS)
extension AUAudioUnit {
    /// How long a view request may take before it is treated as lost.
    public static let viewRequestTimeout: Duration = .seconds(15)

    /// `requestViewController()`, answering `nil` if this instance is invalidated or
    /// ``viewRequestTimeout`` passes first -- either of which leaves Apple's call waiting forever.
    @MainActor
    public func requestViewControllerUnlessInvalidated() async -> NSViewController? {
        let unit = UncheckedBox(value: self)

        do {
            return try await firstToFinish {
                @MainActor in await unit.value.requestViewController()
            } or: {
                try await firstToFinish {
                    await waitForInvalidation(of: unit.value)
                    return nil
                } or: {
                    try await Task.sleep(for: Self.viewRequestTimeout)
                    return nil
                }
            }
        } catch {
            Log.error("* AU view request abandoned:", error)
            return nil
        }
    }
}
#endif
