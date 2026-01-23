// Copyright © 2025 Brad Howes. All rights reserved.

import Models
import Sharing

public final class MockAudioSession: @unchecked Sendable {
  public var active: Bool = false

  public init() {
    @Shared(.mockAudioSession) var mock = self
  }

  public func start() -> Bool {
    active = true
    return active
  }

  public func stop() {
    active = false
  }
}

extension MockAudioSession {

  public var audioSession: AudioSession {
    .init(start: { self.start() }, stop: { self.stop() })
  }
}

extension SharedKey where Self == InMemoryKey<MockAudioSession?>.Default {
  public static var mockAudioSession: Self { Self[.inMemory("mockAudioSession"), default: nil] }
}
