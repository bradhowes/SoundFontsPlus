// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio.AVAudioSession
public import Dependencies

extension DependencyValues {

  public var debounceDurations: DebounceDurations {
    get { self[DebounceDurations.self] }
    set { self[DebounceDurations.self] = newValue }
  }

  public var fileManager: FileManagerClient {
    get { self[FileManagerClient.self] }
    set { self[FileManagerClient.self] = newValue }
  }

#if os(iOS)
  public var outputVolume: OutputVolume {
    get { self[OutputVolume.self] }
    set { self[OutputVolume.self] = newValue }
  }
#endif // os(iOS)

}
