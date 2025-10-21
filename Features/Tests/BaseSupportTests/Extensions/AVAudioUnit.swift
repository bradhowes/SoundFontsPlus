// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio
import Foundation
import Testing

@testable import BaseSupport

@Suite
struct AVAudioUnitTests {

  @Test func midiInstrument() async throws {
    let no = AVAudioUnitReverb()
    #expect(no.midiInstrument == nil)
    let yes = AVAudioUnitSampler()
    #expect(yes.midiInstrument != nil)
  }
}
