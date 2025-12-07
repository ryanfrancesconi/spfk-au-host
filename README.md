# spfk-au-host

Swift based Audio Unit (v3) host and related utilities. 

Doesn't include the actual AVAudioEngine to make the node connections but provides the `AudioEngineConnection` protocol to abstract it with.

```swift
public protocol AudioEngineConnection: Sendable {
    func connectAndAttach(_ node1: AVAudioNode, to node2: AVAudioNode, format: AVAudioFormat?) async throws
}
```
