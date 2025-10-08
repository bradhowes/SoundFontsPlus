// Copyright © 2025 Brad Howes. All rights reserved.

import AudioUnit.AUParameters
import AVFAudio.AVAudioSession
import Dependencies
import DependenciesMacros

/**
 Collection of AVAudioSession dependencies to allow for mocking and controlling in tests.
 Currently only the `Synth` feature interacts with an `AudioSession` instance.
 */
@DependencyClient
public struct AudioSession: Sendable {
  public let setCategory: @Sendable (
    AVAudioSession.Category,
    _ mode: AVAudioSession.Mode,
    _ options: AVAudioSession.CategoryOptions
  ) throws -> Void
  public let sampleRate: @Sendable () -> Double
  public let setPreferredSampleRate: @Sendable (Double) throws -> Void
  public let setPreferredIOBufferDuration: @Sendable (Double) throws -> Void
  public let currentRoute: @Sendable () -> AVAudioSessionRouteDescription
  public let setActive: @Sendable (Bool, _ options: AVAudioSession.SetActiveOptions) throws -> Void

  public init(
    setCategory: @escaping @Sendable (
      AVAudioSession.Category,
      AVAudioSession.Mode,
      AVAudioSession.CategoryOptions
    ) throws -> Void = { _, _, _ in unimplemented() },
    sampleRate: @escaping @Sendable () -> Double = { unimplemented(); return 0.0 },
    setPreferredSampleRate: @escaping @Sendable (Double) throws -> Void = { _ in unimplemented() },
    setPreferredIOBufferDuration: @escaping @Sendable (Double) throws -> Void = { _ in unimplemented() },
    currentRoute: @escaping @Sendable () -> AVAudioSessionRouteDescription = { unimplemented(); return .init() },
    setActive: @escaping @Sendable (
      Bool,
      _ options: AVAudioSession.SetActiveOptions
    ) throws -> Void = { _, _ in unimplemented() }
  ) {
    self.setCategory = setCategory
    self.sampleRate = sampleRate
    self.setPreferredSampleRate = setPreferredSampleRate
    self.setPreferredIOBufferDuration = setPreferredIOBufferDuration
    self.currentRoute = currentRoute
    self.setActive = setActive
  }
}

extension AudioSession: DependencyKey {

  public static var liveValue: AudioSession {
    let session: @Sendable () -> AVAudioSession = { AVAudioSession.sharedInstance() }
    return .init(
      setCategory: {
        try session().setCategory($0, mode: $1, options: $2)
      },
      sampleRate: {
        session().sampleRate
      },
      setPreferredSampleRate: {
        try session().setPreferredSampleRate($0)
      },
      setPreferredIOBufferDuration: {
        try session().setPreferredIOBufferDuration($0)
      },
      currentRoute: {
        session().currentRoute
      },
      setActive: {
        try session().setActive($0, options: $1)
      }
    )
  }

  public static var testingValue: AudioSession {
    let session: @Sendable () -> AVAudioSession = { AVAudioSession.sharedInstance() }
    return .init(
      setCategory: {
        try session().setCategory($0, mode: $1, options: $2)
      },
      sampleRate: {
        session().sampleRate
      },
      setPreferredSampleRate: {
        try session().setPreferredSampleRate($0)
      },
      setPreferredIOBufferDuration: {
        try session().setPreferredIOBufferDuration($0)
      },
      currentRoute: {
        session().currentRoute
      },
      setActive: {
        try session().setActive($0, options: $1)
      }
    )
  }
}
