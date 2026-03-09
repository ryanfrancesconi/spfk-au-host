import Foundation
import Testing

@testable import SPFKAUHost

// MARK: - AudioUnitChainEvent

struct AudioUnitChainEventTests {
    @Test func connectionError() {
        let error = NSError(domain: "test", code: 1)
        let event = AudioUnitChainEvent.connectionError(error: error)

        if case let .connectionError(e) = event {
            #expect((e as NSError).code == 1)
        } else {
            Issue.record("Expected connectionError")
        }
    }

    @Test func willBypass() {
        let event = AudioUnitChainEvent.willBypass(index: 2, state: true)

        if case let .willBypass(index, state) = event {
            #expect(index == 2)
            #expect(state == true)
        } else {
            Issue.record("Expected willBypass")
        }
    }

    @Test func didBypass() {
        let event = AudioUnitChainEvent.didBypass(index: 3, state: false)

        if case let .didBypass(index, state) = event {
            #expect(index == 3)
            #expect(state == false)
        } else {
            Issue.record("Expected didBypass")
        }
    }

    @Test func willRemove() {
        let event = AudioUnitChainEvent.willRemove(index: 1)

        if case let .willRemove(index) = event {
            #expect(index == 1)
        } else {
            Issue.record("Expected willRemove")
        }
    }

    @Test func didRemove() {
        let event = AudioUnitChainEvent.didRemove(index: 4)

        if case let .didRemove(index) = event {
            #expect(index == 4)
        } else {
            Issue.record("Expected didRemove")
        }
    }

    @Test func willInsert() {
        let event = AudioUnitChainEvent.willInsert(index: 0)

        if case let .willInsert(index) = event {
            #expect(index == 0)
        } else {
            Issue.record("Expected willInsert")
        }
    }

    @Test func didInsert() {
        let event = AudioUnitChainEvent.didInsert(index: 5)

        if case let .didInsert(index) = event {
            #expect(index == 5)
        } else {
            Issue.record("Expected didInsert")
        }
    }

    @Test func effectMoved() {
        let event = AudioUnitChainEvent.effectMoved(from: 1, to: 3)

        if case let .effectMoved(from, to) = event {
            #expect(from == 1)
            #expect(to == 3)
        } else {
            Issue.record("Expected effectMoved")
        }
    }
}

// MARK: - AudioUnitCacheEvent

struct AudioUnitCacheEventTests {
    @Test func cachingStarted() {
        let event = AudioUnitCacheEvent.cachingStarted
        if case .cachingStarted = event {
            // pass
        } else {
            Issue.record("Expected cachingStarted")
        }
    }

    @Test func cacheUpdated() {
        let event = AudioUnitCacheEvent.cacheUpdated
        if case .cacheUpdated = event {
            // pass
        } else {
            Issue.record("Expected cacheUpdated")
        }
    }

    @Test func cacheLoaded() {
        let response = SystemComponentsResponse()
        let event = AudioUnitCacheEvent.cacheLoaded(response)

        if case let .cacheLoaded(r) = event {
            #expect(r.results.isEmpty)
        } else {
            Issue.record("Expected cacheLoaded")
        }
    }

    @Test func validating() {
        let event = AudioUnitCacheEvent.validating(name: "AUDelay", completed: 5, count: 20)

        if case let .validating(name, completed, count) = event {
            #expect(name == "AUDelay")
            #expect(completed == 5)
            #expect(count == 20)
        } else {
            Issue.record("Expected validating")
        }
    }
}
