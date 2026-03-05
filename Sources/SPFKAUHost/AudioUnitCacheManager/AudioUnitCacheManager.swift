// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

import AEXML
import AVFoundation
import SPFKBase
import SwiftExtensions

/// Manages caching and validation of Audio Unit components on the system.
public actor AudioUnitCacheManager {
    /// The delegate that receives cache manager events.
    public weak var delegate: AudioUnitCacheManagerDelegate?
    /// Updates the delegate reference.
    public func update(delegate: AudioUnitCacheManagerDelegate?) {
        self.delegate = delegate
    }

    /// Where it writes its xml cache file. Can be set to an alternate directory for testing.
    public var cachesDirectory: URL?
    /// Updates the directory used for writing the XML cache file.
    public func update(cachesDirectory: URL) {
        self.cachesDirectory = cachesDirectory
    }

    var cacheURL: URL?
    /// Updates the URL used for the cache file, falling back to the default location if nil.
    public func update(cacheURL: URL?) {
        self.cacheURL = cacheURL ?? defaultCacheURL()
    }

    private func defaultCacheURL() -> URL? {
        guard let folder = cachesDirectory else {
            return nil
        }

        let filename = "AudioUnitCache.xml"

        // the caches folder might not yet exist
        if !folder.exists {
            do {
                try FileManager.default.createDirectory(
                    at: folder,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            } catch {
                Log.error("Unable to create folder at \(folder.path)")
                return nil
            }
        }

        return folder.appendingPathComponent(filename)
    }

    var cachedComponentCount: Int?

    /// All results including effects that are incompatible
    public private(set) var componentCollection: ComponentCollection?
    func update(componentCollection: ComponentCollection?) {
        self.componentCollection = componentCollection
    }

    func updateEnabled(from value: ComponentCollection) {
        componentCollection?.updateEnabled(from: value)
    }

    /// Updates a specific validation result within the component collection.
    public func update(componentCollectionResult result: ComponentValidationResult) {
        componentCollection?.update(result: result)
    }

    /// Updates the enabled state for a component matching the given audio component description.
    public func update(audioComponentDescription: AudioComponentDescription, isEnabled: Bool) {
        componentCollection?.update(audioComponentDescription: audioComponentDescription, isEnabled: isEnabled)
    }

    /// Task to abort scanning
    var scanTask: Task<[ComponentValidationResult], Error>?

    // MARK: - Observation

    var isScanning: Bool { scanTask != nil }

    // HACK: some special cases to allow through the filter
    var allowedComponentDescriptions = [
        AVAudioUnitVarispeed().audioComponentDescription,
    ]

    /// A textual description of all compatible Audio Units and the cache file path.
    public var debugDescription: String {
        let names = AudioUnitCacheManager.compatibleComponents.map(\.name).sorted()

        var out = "\(names.count) total Audio Unit\(names.pluralString) found\n\n"
        out += names.joined(separator: ", ")
        out += "\n\n"

        if let path = cacheURL?.path {
            out += "Cached at: \(path)"
        }

        return out
    }

    var cacheObservation: AudioUnitCacheObservation = .init()

    /// Creates a new cache manager with an optional caches directory and delegate.
    public init(cachesDirectory: URL? = nil, delegate: AudioUnitCacheManagerDelegate? = nil) {
        self.cachesDirectory = cachesDirectory
        self.delegate = delegate
    }

    /// Stops observation and releases the component collection.
    public func dispose() {
        cacheObservation.stop()
        componentCollection = nil
    }

    deinit {
        Log.debug("- { \(self) }")
    }

    /// Cancels any in-progress component validation scan.
    public func cancelScan() {
        guard isScanning else {
            Log.error("isScanning is false")
            return
        }

        scanTask?.cancel()
    }

    /// load effects cache document
    public func load() async throws {
        // already loaded
        guard componentCollection == nil else {
            assertionFailure("already loaded")
            return
        }

        // request plugins
        Log.debug("*AU Loading cached Audio Units...")

        let loadTask = Task<SystemComponentsResponse, Error> {
            try await loadCache()
        }

        let result = await loadTask.result
        let systemComponentsResponse: SystemComponentsResponse

        switch result {
        case let .success(value):
            systemComponentsResponse = value

        case let .failure(error):
            Log.error(error)

            throw error
        }

        let componentCollection = ComponentCollection(results: systemComponentsResponse.results)
        self.componentCollection = componentCollection

        Log.debug("*AU \(systemComponentsResponse.results.count) Effects are available now.")

        await send(event: .cacheLoaded(systemComponentsResponse))

        cacheObservation.start()
    }

    func send(event: AudioUnitCacheEvent) async {
        guard let delegate else {
            assertionFailure("delegate is nil")
            return
        }

        await delegate.handleAudioUnitCacheManager(event: event)
    }
}

/// Delegate protocol for receiving Audio Unit cache manager events.
public protocol AudioUnitCacheManagerDelegate: AnyObject, Sendable {
    /// Called when the cache manager produces an event such as loading or validation progress.
    func handleAudioUnitCacheManager(event: AudioUnitCacheEvent) async
}
