# SPFKAUHost

[![Version](https://img.shields.io/github/v/tag/ryanfrancesconi/spfk-au-host)](https://github.com/ryanfrancesconi/spfk-au-host/tags)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-au-host%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/ryanfrancesconi/spfk-au-host) [![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-au-host%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/ryanfrancesconi/spfk-au-host)

Audio Unit (v3) hosting, validation, caching, and effects chain management for macOS and iOS.

## Features

- **Effects Chain** — Actor-based `AudioUnitChain` for loading, connecting, bypassing, reordering, and removing Audio Units in a serial chain between input and output nodes
- **Component Caching** — XML-based cache system (`AudioUnitCacheManager`) for persisting validated Audio Unit component state across sessions
- **Component Validation** — Multi-strategy validation pipeline using `AudioComponentValidateWithResults` (macOS 13+/iOS 16+), and external `auval`/`auvaltool` fallback (macOS only)
- **Preset Management** — Factory preset loading via AudioToolbox APIs and user preset discovery from the `~/Library/Audio/Presets` hierarchy (macOS only)
- **Full State Persistence** — Plist-based serialization and restoration of Audio Unit full state dictionaries for project save/load
- **Host Musical Context** — Tempo, time signature, beat position, and transport state blocks for AUs that need host timing information
- **Manufacturer Grouping** — `AudioUnitManufacturerCollection` for organizing available components into manufacturer-grouped hierarchies for menu display
- **Sendable Component Wrapper** — `S_AVAudioUnitComponent` copies all relevant properties from `AVAudioUnitComponent` into a `Sendable` struct for safe cross-isolation use
- **Engine Abstraction** — `AudioEngineConnection` protocol decouples chain connection logic from `AVAudioEngine`, allowing the host to provide its own node attachment strategy
- **Component Observation** — Real-time notifications for Audio Unit registration changes and component invalidation (plugin crash detection)

## Key types

| Type | Description |
|------|-------------|
| **`AudioUnitChain`** | The host: loads, connects, bypasses, reorders and removes Audio Units in a serial chain between an input and an output node |
| **`AudioUnitChainData`** | The fixed-size slot array behind it. Each slot is empty or holds one `AudioUnitDescription` |
| **`AudioUnitDescription`** | One loaded unit and what is known about it |
| **`AudioUnitChainSnapshot`** / **`AudioUnitInsertSnapshot`** | `Sendable` snapshots of the chain and of one slot, safe to pass across isolation |
| **`AudioUnitChainEvent`** / **`AudioUnitChainDelegate`** | What the chain reports back |
| **`AudioUnitCacheManager`** | Component discovery, validation, and the cache that persists it across sessions |
| **`AudioUnitCacheEvent`** / **`AudioUnitCacheObservation`** | Cache progress, and live notification of registration changes and plugin crashes |
| **`AudioUnitValidator`** / **`ComponentValidationResult`** | The validation pipeline and what it concluded |
| **`ComponentCollection`** / **`SystemComponentsResponse`** | The set of components on the system |
| **`AudioUnitManufacturerCollection`** | Those components grouped by manufacturer, for menu display |
| **`AudioUnitAvailability`** | The surface a host implements to supply that list |
| **`S_AVAudioUnitComponent`** | A `Sendable` copy of `AVAudioUnitComponent`'s properties |
| **`AudioUnitPresets`** | Factory preset loading, and user preset discovery under `~/Library/Audio/Presets` |
| **`AudioUnitPresetStorage`** | File-based preset storage for a sandboxed app, in the same folder shape, so `.aupreset` files can be copied in by hand |
| **`AudioUnitStateNotifier`** | Tells parameter listeners the state changed — what makes an open plugin UI follow a preset load |
| **`HostAUState`** / **`HostMusicalContext`** / **`HostTransportState`** | Tempo, time signature, beat position and transport state for units that need host timing. Mutations are reflected live, so nothing has to reassign the blocks |
| **`AudioEngineConnection`** | Decouples chain connection from `AVAudioEngine`, so the host supplies its own attachment strategy |
| **`AudioEngineNode`** / **`NodeInputAccess`** / **`NodeOutputAccess`** | What the chain needs of the nodes at either end |
| **`AudioUnitTestContent`** | Known-good components for tests to load against |

## Dependencies

| Package | Description |
|---|---|
| [SPFKAudioBase](https://github.com/ryanfrancesconi/spfk-audio-base) | Shared audio type definitions |
| [SPFKUtils](https://github.com/ryanfrancesconi/spfk-utils) | Plist utilities, process handling, and audio extensions |
| [SPFKTesting](https://github.com/ryanfrancesconi/spfk-testing) | Test case base classes (test target only) |

## Platform Notes

Most functionality is cross-platform. The following features are macOS-only:

- **External `auval` validation** — Falls back to `AudioComponentValidateWithResults` API results on iOS
- **User preset discovery** — `AudioUnitPresets.Locations` and `~/Library/Audio/Presets` browsing are unavailable on iOS; factory preset loading and full state persistence work on both platforms

## Requirements

- **Platforms:** macOS 13+, iOS 16+
- **Swift:** 6.2+

## About

Spongefork is the personal software projects of musician and developer [Ryan Francesconi](https://spongefork.com). Dedicated to creative sound manipulation, his first application, Spongefork, was released in 1999 for macOS 8. From 2026, Spongefork returns as his software container for more musical experimentation. In addition to [software releases](https://spongefork.com/shadowtag/), open source components can be found on his [GitHub page](https://github.com/ryanfrancesconi).
