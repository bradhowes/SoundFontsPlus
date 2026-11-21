// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio.AVAudioSession
import DependenciesTestSupport
import Foundation
import Testing

@testable import Models

@Suite
struct AudioSessionTests {

  @Test
  func liveClient() async throws {
    let uat = AudioSession.liveValue
    await #expect(throws: Never.self) {
      await uat.start()
    }
    await #expect(throws: Never.self) {
      await uat.stop()
    }
  }
}
