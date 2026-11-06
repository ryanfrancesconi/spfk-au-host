# SPFKAUHost

[![Version](https://img.shields.io/github/v/tag/ryanfrancesconi/spfk-au-host)](https://github.com/ryanfrancesconi/spfk-au-host/tags)
[![Swift](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-au-host%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/ryanfrancesconi/spfk-au-host) [![Platforms](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-au-host%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/ryanfrancesconi/spfk-au-host)

Audio Unit hosting for `AVAudioEngine`: finding the units installed on the system, validating them,
and running a chain of them as inserts in a signal path.

## Features

- Scan and validate installed components, with the results cached as JSON. Later launches validate
  only what was added or updated since the cache was written.
- Pick up plugins installed or removed while the app runs
- Validate with `auval` on macOS, for units the system does not pass or for every unit
- An `AudioUnitChain` actor with a fixed number of insert slots between an input and an output node.
  Insert, bypass, swap and remove by slot index; the chain reconnects after each change.
- Snapshot and restore a chain with each unit's full state
- Factory presets, user presets in `~/Library/Audio/Presets`, and `AudioUnitPresetStorage` for
  presets kept in the same folder layout
- `HostAUState` supplies tempo, time signature, beat position and transport state to hosted units
- Group available components by manufacturer (`AudioUnitManufacturerCollection`)

## Usage

```swift
let cache = AudioUnitCacheManager(cachesDirectory: cachesURL, delegate: self)
do { try await cache.load() } catch { /* no cache yet */ }
try await cache.refreshCache()
```

The chain's delegate is an `AudioUnitChainDelegate`, which attaches and connects nodes in your
engine:

```swift
let chain = AudioUnitChain(delegate: host)
try await chain.updateIO(input: player, output: mixer)
try await chain.insertAudioUnit(componentDescription: delay, at: 0)
try await chain.bypassEffect(at: 0, isBypassed: true)
```

## Notes

- The cache manager and the chain hold their delegates weakly. Keep the delegate alive while either
  is in use.
- The chain never touches an engine directly. Its delegate does every attach and connect.
- Inserts are stereo. A unit with a mono input is refused.
- `auval` validation and the user preset folders are macOS only.

## About

Spongefork is the personal software projects of musician and developer [Ryan Francesconi](https://spongefork.com). Dedicated to creative sound manipulation, his first application, Spongefork, was released in 1999 for macOS 8. From 2026, Spongefork returns as his software container for more musical experimentation. In addition to [software releases](https://spongefork.com/shadowtag/), open source components can be found on his [GitHub page](https://github.com/ryanfrancesconi).
