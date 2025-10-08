// Copyright © 2025 Brad Howes. All rights reserved.

import Dependencies

extension DependencyValues {

  public var audioSession: AudioSession {
    get { self[AudioSession.self] }
    set { self[AudioSession.self] = newValue }
  }

  public var fileManager: FileManagerClient {
    get { self[FileManagerClient.self] }
    set { self[FileManagerClient.self] = newValue }
  }
}
