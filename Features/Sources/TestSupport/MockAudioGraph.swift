// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio.AVAudioEngine
import Models
import Sharing

public final class MockAudioGraph: @unchecked Sendable {
  public var active: Bool = false

  public init() {
    @Shared(.mockAudioGraph) var mock = self
  }

  public func start(audioUnit: AVAudioUnitMIDIInstrument?) -> Bool {
    active = true
    return active
  }

  public func stop(audioUnit: AVAudioUnitMIDIInstrument?) {
    active = false
  }
}

extension MockAudioGraph {

  public var audioGraph: AudioGraph {
    .init(
      engine: nil,
      start: { _, audioUnit in self.start(audioUnit: audioUnit) },
      stop: { _, audioUnit in self.stop(audioUnit: audioUnit) }
    )
  }
}

extension SharedKey where Self == InMemoryKey<MockAudioGraph?>.Default {
  public static var mockAudioGraph: Self { Self[.inMemory("mockAudioGraph"), default: nil] }
}
