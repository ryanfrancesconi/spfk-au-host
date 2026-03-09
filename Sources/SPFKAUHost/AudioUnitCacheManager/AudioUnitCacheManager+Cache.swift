// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

import AVFoundation
import SPFKAudioBase
import SPFKBase
import SwiftExtensions

// MARK: - Codable Cache Types

/// A single cached audio unit entry for JSON persistence.
private struct CachedAudioUnit: Codable {
    let name: String
    let manufacturerName: String
    let typeName: String
    let version: String
    let componentType: UInt32
    let componentSubType: UInt32
    let componentManufacturer: UInt32
    let componentFlags: UInt32
    let componentFlagsMask: UInt32
    let validation: String
    let isEnabled: Bool
}

/// The top-level JSON wrapper for the audio unit cache file.
private struct CachedAudioUnitCollection: Codable {
    let cachedComponentUIDs: [String]
    let audioUnits: [CachedAudioUnit]
}

// MARK: - Cache

extension AudioUnitCacheManager {
    /// Whether the set of system components differs from the cached set, indicating a rescan is needed.
    public var validationIsNeeded: Bool {
        let systemUIDs = Set(cachedCompatibleComponents().map(\.audioComponentDescription.uid))
        return systemUIDs != cachedComponentUIDs
    }

    private func loadCacheData() throws -> CachedAudioUnitCollection {
        guard let cacheURL else {
            throw NSError(description: "*AU nil cache URL")
        }

        guard cacheURL.exists else {
            throw NSError(description: "*AU cache file wasn't found")
        }

        let data = try Data(contentsOf: cacheURL)
        let collection = try JSONDecoder().decode(CachedAudioUnitCollection.self, from: data)

        Log.debug("*AU Parsed", cacheURL.path)

        return collection
    }

    // MARK: - Loading

    /// Load AudioComponentDescription list from the JSON cache file.
    func loadCache() async throws -> SystemComponentsResponse {
        cachedComponentUIDs = nil
        let collection = try loadCacheData()
        return parse(cache: collection)
    }

    private func parse(cache collection: CachedAudioUnitCollection) -> SystemComponentsResponse {
        cachedComponentUIDs = Set(collection.cachedComponentUIDs)

        var results = collection.audioUnits.compactMap { item in
            parse(cacheItem: item)
        }

        results.sort { $0.manufacturerName < $1.manufacturerName }

        return SystemComponentsResponse(results: results)
    }

    private func parse(cacheItem item: CachedAudioUnit) -> ComponentValidationResult? {
        let audioComponentDescription = AudioComponentDescription(
            componentType: item.componentType,
            componentSubType: item.componentSubType,
            componentManufacturer: item.componentManufacturer,
            componentFlags: item.componentFlags,
            componentFlagsMask: item.componentFlagsMask
        )

        var component: AVAudioUnitComponent?

        if item.isEnabled,
           let avComponent = AVAudioUnitComponentManager.shared()
           .components(matching: audioComponentDescription)
           .first
        {
            component = avComponent
        }

        var validationResult: AudioComponentValidationResult?

        if let value = AudioComponentValidationResult(description: item.validation) {
            validationResult = value
        }

        let validation = AudioUnitValidator.ValidationResult(result: validationResult ?? .passed)

        let result: ComponentValidationResult =
            if let component {
                ComponentValidationResult(
                    audioComponentDescription: audioComponentDescription,
                    component: component,
                    validation: validation,
                    isEnabled: item.isEnabled
                )
            } else {
                ComponentValidationResult(
                    audioComponentDescription: audioComponentDescription,
                    validation: validation,
                    isEnabled: item.isEnabled,
                    name: item.name,
                    typeName: item.typeName,
                    manufacturerName: item.manufacturerName,
                    versionString: item.version
                )
            }

        return result
    }

    // MARK: - Creating

    /// Called to refresh the internal Audio Unit cache by collecting system AUs
    /// - Parameter completionHandler: handler
    public func createCache() async throws {
        await send(event: .cachingStarted)

        // preserve previous enabled values...

        let previousCollection = componentCollection

        removeCache()

        let results = try await validate()

        update(componentCollection: ComponentCollection(results: results))

        // reapply isEnabled or if missing true
        if let value = previousCollection {
            updateEnabled(from: value)
        }

        try await writeCache()

        await send(event: .cacheUpdated)
    }

    // MARK: - Writing

    /// Write current component collection to disk as JSON.
    public func writeCache() async throws {
        guard let cacheURL else {
            throw NSError(description: "*AU cacheURL is nil")
        }

        guard let effects: [ComponentValidationResult] = componentCollection?.validationResults else {
            throw NSError(description: "*AU componentCollection is nil")
        }

        removeCache()

        let componentUIDs = cachedCompatibleComponents().map(\.audioComponentDescription.uid).sorted()

        let audioUnits = effects.map { au -> CachedAudioUnit in
            let acd = au.audioComponentDescription
            return CachedAudioUnit(
                name: au.name,
                manufacturerName: au.manufacturerName,
                typeName: au.typeName,
                version: au.versionString,
                componentType: acd.componentType,
                componentSubType: acd.componentSubType,
                componentManufacturer: acd.componentManufacturer,
                componentFlags: acd.componentFlags,
                componentFlagsMask: acd.componentFlagsMask,
                validation: au.validation.result.description,
                isEnabled: au.isEnabled
            )
        }

        let collection = CachedAudioUnitCollection(
            cachedComponentUIDs: componentUIDs,
            audioUnits: audioUnits
        )

        Log.debug("*AU Writing cache to", cacheURL)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(collection)

        try data.write(to: cacheURL)

        Log.debug("*AU Wrote cache to", cacheURL)
    }

    func removeCache() {
        guard let cacheURL, cacheURL.exists else { return }

        do {
            try cacheURL.delete()
            Log.debug("*AU Deleted", cacheURL)

        } catch {
            Log.error("*AU Failed to delete cache file...", error.localizedDescription)
        }
    }
}
