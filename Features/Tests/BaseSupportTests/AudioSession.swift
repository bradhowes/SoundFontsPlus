// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio.AVAudioSession
import Foundation
import Testing

@testable import BaseSupport

@Suite
struct AudioSessionTests {

  @Test
  func liveClient() throws {
    let audioFormat: AVAudioFormat! = AVAudioFormat(
      commonFormat: .pcmFormatFloat32,
      sampleRate: 48_000.0,
      channels: 2,
      interleaved: false
    )

    let uat = AudioSession.liveValue
    #expect(throws: Never.self) {
      uat.start(audioFormat)
    }
    #expect(throws: Never.self) {
      uat.stop()
    }
  }
}
