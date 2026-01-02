// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio.AVAudioSession
import Foundation
import Testing

@testable import BaseSupport

@Suite
struct AudioSessionTests {

  @Test
  func liveClient() throws {
    let uat = AudioSession.liveValue
    #expect(throws: Never.self) {
      uat.start()
    }
    #expect(throws: Never.self) {
      uat.stop()
    }
  }
}
