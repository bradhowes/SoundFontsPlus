// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio.AVAudioSession
import Foundation
import Sharing
import Testing

@testable import Synth

@Suite
struct AudioGraphTests {

  @Test
  func liveClientMissingComponents() async throws {
    let uat = AudioGraph.liveValue
    #expect(throws: Never.self) {
      #expect(uat.start(nil) == false)
    }
    #expect(throws: Never.self) {
      uat.stop(nil)
    }
  }

  @Test
  func liveClientHasComponents() async throws {

    let audioUnit = AVAudioUnitSampler()
    let uat = AudioGraph.liveValue
    #expect(throws: Never.self) {
      #expect(uat.start(audioUnit) == true)
    }
    #expect(throws: Never.self) {
      uat.stop(audioUnit)
    }
  }

  @Test
  func previewClient() throws {
    let uat = AudioGraph.previewValue
    #expect(throws: Never.self) {
      #expect(uat.start(AVAudioUnitMIDIInstrument()) == true)
    }
    #expect(throws: Never.self) {
      uat.stop(AVAudioUnitMIDIInstrument())
    }
  }
}
