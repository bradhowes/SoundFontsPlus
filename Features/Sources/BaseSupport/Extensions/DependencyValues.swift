// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio.AVAudioSession
import Dependencies

extension DependencyValues {

  public var audioGraph: AudioGraph {
    get { self[AudioGraph.self] }
    set { self[AudioGraph.self] = newValue }
  }

  public var audioSession: AudioSession {
    get { self[AudioSession.self] }
    set { self[AudioSession.self] = newValue }
  }

  public var debounceDurations: DebounceDurations {
    get { self[DebounceDurations.self] }
    set { self[DebounceDurations.self] = newValue }
  }

  public var fileManager: FileManagerClient {
    get { self[FileManagerClient.self] }
    set { self[FileManagerClient.self] = newValue }
  }

  public var outputVolume: OutputVolume {
    get { self[OutputVolume.self] }
    set { self[OutputVolume.self] = newValue }
  }

  public var synthAUv3ComponentDescription: AudioComponentDescription {
    get { self[SynthAUv3ComponentDescription.self] }
    set { self[SynthAUv3ComponentDescription.self] = newValue }
  }
}
