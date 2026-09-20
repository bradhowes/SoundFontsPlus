// Copyright © 2025 Brad Howes. All rights reserved.

public import Models
public import Sharing

public final class MockAudioSession: @unchecked Sendable {
  public var active: Bool = false

  public init() {
    @Shared(.mockAudioSession) var mock = self
  }

  public func start() async -> Bool {
    active = true
    return active
  }

  public func stop() async {
    active = false
  }
}

extension MockAudioSession {

  public var audioSession: AudioSession {
    .init(start: { await self.start() }, stop: { await self.stop() })
  }
}

extension SharedKey where Self == InMemoryKey<MockAudioSession?>.Default {
  public static var mockAudioSession: Self { Self[.inMemory("mockAudioSession"), default: nil] }
}
