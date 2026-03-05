// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

import AVFoundation
import Foundation
import SPFKBase

/// Observes system notifications for Audio Unit component registration changes and invalidations.
public final class AudioUnitCacheObservation {
    /// Events that can occur when the system's Audio Unit registrations change.
    public enum Event: Sendable {
        /// The set of available audio components on the system has changed.
        case componentRegistrationsChanged
        /// A specific audio component instance was invalidated (e.g., crashed).
        case componentInvalidated(AudioComponentDescription)
    }

    /// Closure invoked when an observation event occurs.
    public var eventHandler: (@Sendable (Event) -> Void)?

    var notificationTask: Task<Void, Error>?

    var isObserving = false

    /// Creates a new cache observation instance.
    public init() {}

    /// Begins observing system notifications for component registration and invalidation changes.
    public func start() {
        guard !isObserving else { return }

        Log.debug("adding observers...")

        // Sign up for a notification when the list of available components changes.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(componentRegistrationObserver),
            name: .componentRegistrationsChanged,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(componentInstanceObserver),
            name: .componentInstanceInvalidation,
            object: nil
        )

        isObserving = true
    }

    /// Stops observing system notifications and removes all registered observers.
    public func stop() {
        guard isObserving else { return }

        Log.debug("removing observers...")

        NotificationCenter.default.removeObserver(self, name: .componentRegistrationsChanged, object: nil)
        NotificationCenter.default.removeObserver(self, name: .componentInstanceInvalidation, object: nil)

        isObserving = false
    }

    @objc private func componentInstanceObserver(notification: Notification) {
        guard let crashedAU = notification.object as? AUAudioUnit else {
            return
        }

        Log.error("* Audio Unit Crashed: \(crashedAU.debugDescription)")

        guard let eventHandler else { return }

        eventHandler(.componentInvalidated(crashedAU.componentDescription))
    }

    @objc private func componentRegistrationObserver(notification: Foundation.Notification) {
        Log.debug("*AU Triggering: componentRegistrationsChanged event *")

        triggerComponentRegistrationEvent()
    }

    private func triggerComponentRegistrationEvent() {
        guard let eventHandler else { return }

        // delay the event, it comes in fairly early before some installations are complete
        notificationTask?.cancel()
        notificationTask = Task<Void, Error> { [eventHandler] in
            try await Task.sleep(seconds: 2)
            try Task.checkCancellation()

            eventHandler(.componentRegistrationsChanged)
        }
    }
}

extension Notification.Name {
    /// Notification generated when the set of available AudioComponents changes.
    static let componentRegistrationsChanged = Notification.Name(
        rawValue: kAudioComponentRegistrationsChangedNotification as String
    )

    /// This notification can happen for several reasons, for instance the connection being
    /// invalidated or the process abnormally ending. There can be multiple notifications for
    /// the same event (i.e. a terminated process will also invalidate the connection).
    static let componentInstanceInvalidation = Notification.Name(
        rawValue: kAudioComponentInstanceInvalidationNotification as String
    )
}
