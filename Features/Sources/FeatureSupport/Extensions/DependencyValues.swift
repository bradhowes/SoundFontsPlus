// Copyright © 2025 Brad Howes. All rights reserved.

import AudioUnit.AUParameters
import AVFAudio.AVAudioSession
import Dependencies
import DependenciesMacros

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
}

extension AudioSession: DependencyKey {
  public static var liveValue: AudioSession {
    let session: @Sendable () -> AVAudioSession = { AVAudioSession.sharedInstance() }
    return .init(
      setCategory: { try session().setCategory($0, mode: $1, options: $2) },
      sampleRate: { session().sampleRate },
      setPreferredSampleRate: { try session().setPreferredSampleRate($0) },
      setPreferredIOBufferDuration: { try session().setPreferredIOBufferDuration($0) },
      currentRoute: { session().currentRoute },
      setActive: { try session().setActive($0, options: $1) }
    )
  }
}

extension AUParameterTree: @retroactive TestDependencyKey {}

extension AUParameterTree: @retroactive DependencyKey {
  public static var liveValue: AUParameterTree { ParameterAddress.createParameterTree() }
  public static var previewValue: AUParameterTree { ParameterAddress.createParameterTree() }
  public static var testValue: AUParameterTree { ParameterAddress.createParameterTree() }
}

extension DependencyValues {

  public var audioSession: AudioSession {
    get { self[AudioSession.self] }
    set { self[AudioSession.self] = newValue }
  }

  public var parameters: AUParameterTree {
    get { self[AUParameterTree.self] }
    set { self[AUParameterTree.self] = newValue }
  }
}
