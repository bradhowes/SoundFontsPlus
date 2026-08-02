// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio.AVAudioSession
public import Dependencies

extension DependencyValues {

  public var appActiveState: AppActiveState {
    get { self[AppActiveState.self] }
    set { self[AppActiveState.self] = newValue }
  }

  public var audioGraph: AudioGraph {
    get { self[AudioGraph.self] }
    set { self[AudioGraph.self] = newValue }
  }

  public var audioSession: AudioSession {
    get { self[AudioSession.self] }
    set { self[AudioSession.self] = newValue }
  }

  public var delayDevice: DelayDevice {
    get { self[DelayDevice.self] }
    set { self[DelayDevice.self] = newValue }
  }

  public var reverbDevice: ReverbDevice {
    get { self[ReverbDevice.self] }
    set { self[ReverbDevice.self] = newValue }
  }
}
