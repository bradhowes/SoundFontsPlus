// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio.AVAudioSession
import Foundation
import Sharing
import Testing

@testable import BaseSupport

@Suite
struct AudioGraphTests {

  @Test func liveClientMissingComponents() throws {
    let audioFormat: AVAudioFormat! = AVAudioFormat(
      commonFormat: .pcmFormatFloat32,
      sampleRate: 48_000.0,
      channels: 2,
      interleaved: false
    )

    let uat = AudioGraph.liveValue
    #expect(throws: Never.self) {
      #expect(uat.start(audioFormat) == false)
    }
    #expect(throws: Never.self) {
      uat.stop()
    }
  }

  @Test func liveClientHasComponents() throws {
    @Shared(.audioEngine) var audioEngine = AVAudioEngine()
    @Shared(.delayEffect) var delayEffect = AVAudioUnitDelay()
    @Shared(.reverbEffect) var reverbEffect = AVAudioUnitReverb()

    let audioFormat: AVAudioFormat! = AVAudioFormat(
      commonFormat: .pcmFormatFloat32,
      sampleRate: 48_000.0,
      channels: 2,
      interleaved: false
    )

    let uat = AudioGraph.liveValue
    #expect(throws: Never.self) {
      #expect(uat.start(audioFormat) == false)
    }
    #expect(throws: Never.self) {
      uat.stop()
    }
  }

  @Test func previewClient() throws {
    let audioFormat: AVAudioFormat! = AVAudioFormat(
      commonFormat: .pcmFormatFloat32,
      sampleRate: 48_000.0,
      channels: 2,
      interleaved: false
    )

    let uat = AudioGraph.previewValue
    #expect(throws: Never.self) {
      #expect(uat.start(audioFormat) == true)
    }
    #expect(throws: Never.self) {
      uat.stop()
    }
  }
}
