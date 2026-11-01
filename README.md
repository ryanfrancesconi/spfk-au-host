# SPFKAUHost

[![Version](https://img.shields.io/github/v/tag/ryanfrancesconi/spfk-au-host)](https://github.com/ryanfrancesconi/spfk-au-host/tags)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-au-host%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/ryanfrancesconi/spfk-au-host) [![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-au-host%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/ryanfrancesconi/spfk-au-host)

Audio Unit hosting for an `AVAudioEngine` app: finding the units installed on the system, deciding
which of them are safe to load, and running a chain of them as inserts in a signal path.

A host that offers plugins to its users has three problems AVFoundation leaves to it. Scanning and
validating every installed unit is slow, so the result has to be cached and kept current as plugins
are installed, updated and removed. Some plugins fail validation, so the host needs a verdict before
it loads one. And an effects chain is more than a list of `AVAudioUnit`s: slots are filled,
bypassed, reordered and emptied while audio runs, and a saved document has to reopen with the same
units in the same state.

ShadowTag hosts its effects inserts with this package, through spfk-audio-workspace. It depends on
neither product and can be adopted on its own.

## What it does

**Discovery and validation.** `AudioUnitCacheManager` scans the system's components, validates them,
and writes the verdicts to a JSON cache. Later launches read the cache and validate only what was
added or updated since it was written. While loaded it observes component registration, so a plugin
installed or removed while the app runs is picked up. On macOS, a unit the system does not pass is
decided by `auval`, which can also be asked to decide every unit.

**The chain.** `AudioUnitChain` is an actor holding a fixed number of insert slots between an input
node and an output node. Units are inserted, bypassed, swapped and removed by slot index, and the
chain reconnects itself after each change. A bypassed slot is taken out of the signal path rather
than left connected. The chain never touches an engine directly: its delegate does every attach and
connect, so it fits whatever engine ownership the app already has.

**State.** A chain can be snapshotted and restored with each unit's full state, so a document can
persist its effects. Factory presets load through AudioToolbox, user presets are found in the
standard `~/Library/Audio/Presets` folders on macOS, and `AudioUnitPresetStorage` keeps presets in
that same folder shape for an app that manages its own.

**Host context.** `HostAUState` supplies tempo, time signature, beat position and transport state to
units that ask their host for them, such as tempo-synced delays.

**Menus.** The available components can be grouped by manufacturer for building a plugin menu.

## Usage

Load the component cache, then bring it up to date with the system:

```swift
let cache = AudioUnitCacheManager(cachesDirectory: cachesURL, delegate: self)
do { try await cache.load() } catch { /* no cache yet */ }
try await cache.refreshCache()
```

Run a chain between two nodes. The delegate is an `AudioUnitChainDelegate`, which attaches and
connects nodes in your engine:

```swift
let chain = AudioUnitChain(delegate: host)
try await chain.updateIO(input: player, output: mixer)
try await chain.insertAudioUnit(componentDescription: delay, at: 0)
try await chain.bypassEffect(at: 0, isBypassed: true)
```

## Things to know

- Both the cache manager and the chain hold their delegate weakly, and report everything through it.
  Keep the delegate alive for as long as either is in use.
- Inserts are stereo. A unit with a mono input is refused.
- `auval` validation and the user preset folders are macOS only.

## About

Spongefork is the personal software projects of musician and developer [Ryan Francesconi](https://spongefork.com). Dedicated to creative sound manipulation, his first application, Spongefork, was released in 1999 for macOS 8. From 2026, Spongefork returns as his software container for more musical experimentation. In addition to [software releases](https://spongefork.com/shadowtag/), open source components can be found on his [GitHub page](https://github.com/ryanfrancesconi).
