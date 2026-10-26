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
    /// The result's description, as caches written before `validationResult` stored it. Read, never written.
    var validation: String?
    /// `AudioComponentValidationResult.rawValue`.
    var validationResult: UInt32?
    var reason: String?
    let isEnabled: Bool
}

/// The top-level JSON wrapper for the audio unit cache file.
private struct CachedAudioUnitCollection: Codable {
    let cachedComponentUIDs: [String]
    let audioUnits: [CachedAudioUnit]
}

// MARK: - Cache

extension AudioUnitCacheManager {
    /// Whether the system's components differ from the cached set, or any has been updated since
    /// it was validated.
    public var validationIsNeeded: Bool {
        let components = cachedCompatibleComponents()
        let systemUIDs = Set(components.map(\.audioComponentDescription.uid))
        return systemUIDs != cachedComponentUIDs || !outdatedUIDs(in: components).isEmpty
    }

    /// Cached entries whose installed version differs from the one they were validated on.
    private func outdatedUIDs(in components: [AVAudioUnitComponent]) -> Set<String> {
        guard let results = componentCollection?.validationResults else { return [] }

        let installedVersions = Dictionary(
            components.map { ($0.audioComponentDescription.uid, $0.versionString) },
            uniquingKeysWith: { first, _ in first }
        )

        return Set(results.compactMap { result in
            let uid = result.audioComponentDescription.uid
            guard let installed = installedVersions[uid], installed != result.validatedVersionString else { return nil }
            return uid
        })
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

        // Build a UID → component map once so parse(cacheItem:) doesn't call
        // AVAudioUnitComponentManager.components(matching:) once per cached AU.
        let componentsByUID = Dictionary(
            cachedCompatibleComponents().map { ($0.audioComponentDescription.uid, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        var results = collection.audioUnits.compactMap { item in
            parse(cacheItem: item, componentsByUID: componentsByUID)
        }

        results.sort { $0.manufacturerName < $1.manufacturerName }

        return SystemComponentsResponse(results: results)
    }

    private func parse(cacheItem item: CachedAudioUnit, componentsByUID: [String: AVAudioUnitComponent]) -> ComponentValidationResult? {
        let audioComponentDescription = AudioComponentDescription(
            componentType: item.componentType,
            componentSubType: item.componentSubType,
            componentManufacturer: item.componentManufacturer,
            componentFlags: item.componentFlags,
            componentFlagsMask: item.componentFlagsMask
        )

        var component: AVAudioUnitComponent?

        if item.isEnabled {
            component = componentsByUID[audioComponentDescription.uid]
        }

        let validationResult = item.validationResult.flatMap(AudioComponentValidationResult.init(rawValue:))
            ?? item.validation.flatMap(AudioComponentValidationResult.init(description:))

        if validationResult == nil {
            // Unreadable, so the next refresh treats it as new and validates it again.
            cachedComponentUIDs?.remove(audioComponentDescription.uid)
        }

        let validation = AudioUnitValidator.ValidationResult(result: validationResult ?? .unknown, reason: item.reason)

        let result: ComponentValidationResult =
            if let component {
                ComponentValidationResult(
                    audioComponentDescription: audioComponentDescription,
                    component: component,
                    validation: validation,
                    isEnabled: item.isEnabled,
                    validatedVersionString: item.version
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

    /// Validates every system AU and rewrites the cache. `forceExternal` has `auval` decide each
    /// third-party plugin rather than accept the system's stored verdict.
    public func createCache(forceExternal: Bool = false) async throws {
        try await runScan { [self] in try await performCreateCache(forceExternal: forceExternal) }
        try await updateCacheIfRegistrationChanged()
    }

    private func performCreateCache(forceExternal: Bool) async throws {
        await send(event: .cachingStarted)

        // preserve previous enabled values...

        let previousCollection = componentCollection

        let components = cachedCompatibleComponents()
        let componentUIDs = Set(components.map(\.audioComponentDescription.uid))
        let results = try await validate(components: components, forceExternal: forceExternal)

        update(componentCollection: ComponentCollection(results: results))
        cachedComponentUIDs = componentUIDs

        // reapply isEnabled or if missing true
        if let value = previousCollection {
            updateEnabled(from: value)
        }

        try await writeCache(componentUIDs: componentUIDs)

        await send(event: .cacheUpdated)

        let failed = componentCollection?.failedEffects ?? []
        if !failed.isEmpty {
            await send(event: .validationComplete(failed: failed))
        }
    }

    // MARK: - Writing

    /// Write current component collection to disk as JSON, recording `componentUIDs` as the
    /// components it was validated against. Replaces any previous file only once written.
    public func writeCache(componentUIDs: Set<String>) async throws {
        guard let cacheURL else {
            throw NSError(description: "*AU cacheURL is nil")
        }

        guard let effects: [ComponentValidationResult] = componentCollection?.validationResults else {
            throw NSError(description: "*AU componentCollection is nil")
        }

        let audioUnits = effects.map { au -> CachedAudioUnit in
            let acd = au.audioComponentDescription
            return CachedAudioUnit(
                name: au.name,
                manufacturerName: au.manufacturerName,
                typeName: au.typeName,
                version: au.validatedVersionString,
                componentType: acd.componentType,
                componentSubType: acd.componentSubType,
                componentManufacturer: acd.componentManufacturer,
                componentFlags: acd.componentFlags,
                componentFlagsMask: acd.componentFlagsMask,
                validationResult: au.validation.result.rawValue,
                reason: au.validation.reason,
                isEnabled: au.isEnabled
            )
        }

        let collection = CachedAudioUnitCollection(
            cachedComponentUIDs: componentUIDs.sorted(),
            audioUnits: audioUnits
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(collection)

        try data.write(to: cacheURL, options: .atomic)

        Log.debug("*AU Wrote cache to", cacheURL)
    }

    // MARK: - Incremental Update

    /// Brings a loaded cache in line with the system's components, validating only those added or updated
    /// since it was written. With no cache loaded, validates everything.
    public func refreshCache() async throws {
        guard componentCollection != nil else {
            try await createCache()
            return
        }

        try await updateCache()
    }

    /// Incrementally updates the cache to the system's current components.
    /// Validates only components added or updated since the cache was written, and removes stale entries.
    func updateCache() async throws {
        try await runScan { [self] in try await performUpdateCache() }
        try await updateCacheIfRegistrationChanged()
    }

    private func performUpdateCache() async throws {
        let freshComponents = cachedCompatibleComponents()
        let systemUIDs = Set(freshComponents.map(\.audioComponentDescription.uid))

        let updatedUIDs = outdatedUIDs(in: freshComponents)

        guard systemUIDs != cachedComponentUIDs || !updatedUIDs.isEmpty else {
            Log.debug("*AU components unchanged, skipping rescan")
            return
        }

        let previousUIDs = cachedComponentUIDs ?? []
        let newUIDs = systemUIDs.subtracting(previousUIDs).union(updatedUIDs)
        let removedUIDs = previousUIDs.subtracting(systemUIDs)

        // Mutate a local copy; componentCollection setter is private to its defining file
        var updated = componentCollection

        if !removedUIDs.isEmpty {
            updated?.remove(uids: removedUIDs)
            Log.debug("*AU removed \(removedUIDs.count) stale AU(s)")
        }

        if !newUIDs.isEmpty {
            let newComponents = freshComponents.filter { newUIDs.contains($0.audioComponentDescription.uid) }
            Log.debug("*AU validating \(newComponents.count) new or updated AU(s)")

            if newComponents.count > 1 {
                await send(event: .cachingStarted)
            }

            let newResults = try await validate(components: newComponents)
            for result in newResults {
                updated?.insert(result: result)
            }
        }

        update(componentCollection: updated)
        cachedComponentUIDs = systemUIDs

        try await writeCache(componentUIDs: systemUIDs)
        await send(event: .cacheUpdated)

        let failed = componentCollection?.failedEffects ?? []
        if !failed.isEmpty {
            await send(event: .validationComplete(failed: failed))
        }
    }

    /// Catches up with a registration change that arrived while a scan was running.
    private func updateCacheIfRegistrationChanged() async throws {
        guard registrationChangedDuringScan else { return }
        registrationChangedDuringScan = false
        try await updateCache()
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
