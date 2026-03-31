// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio.AVAudioSession
import Foundation
import Models
import Sharing
import Testing

@testable import Synth

@Suite
struct AudioGraphTests {

  @Test
  func liveClientMissingComponents() async throws {
    let uat = AudioGraph.liveValue
    #expect(throws: Never.self) { #expect(uat.start(uat.engine, nil) == false) }
    #expect(throws: Never.self) { uat.stop(uat.engine, nil) }
  }

  @Test
  func liveClientHasComponents() async throws {

    let audioUnit = AVAudioUnitSampler()
    let uat = AudioGraph.liveValue
    #expect(throws: Never.self) {
      #expect(uat.start(uat.engine, audioUnit) == true)
    }
    #expect(throws: Never.self) {
      uat.stop(uat.engine, audioUnit)
    }
  }

  @Test
  func previewClient() throws {
    let uat = AudioGraph.previewValue
    #expect(throws: Never.self) {
      #expect(uat.start(uat.engine, AVAudioUnitMIDIInstrument()) == true)
    }
    #expect(throws: Never.self) {
      uat.stop(uat.engine, AVAudioUnitMIDIInstrument())
    }
  }
}
