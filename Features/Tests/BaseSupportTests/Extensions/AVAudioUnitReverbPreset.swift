// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio
import Foundation
import Testing

@testable import BaseSupport

@Suite
struct AVAudioUnitReverbPresetTests {

  @Test func idProperty() async throws {
    let preset0 = AVAudioUnitReverbPreset(rawValue: 0)
    #expect(preset0?.id == AVAudioUnitReverbPreset.smallRoom.rawValue)
  }

  @Test func range() async throws {
    #expect(AVAudioUnitReverbPreset.range == 0...12)
  }

  @Test func name() async throws {
    #expect(AVAudioUnitReverbPreset(rawValue: 0)?.name == "Room 1")
    #expect(AVAudioUnitReverbPreset(rawValue: 1)?.name == "Room 2")
    #expect(AVAudioUnitReverbPreset(rawValue: 2)?.name == "Room 3")
    #expect(AVAudioUnitReverbPreset(rawValue: 3)?.name == "Hall 1")
    #expect(AVAudioUnitReverbPreset(rawValue: 4)?.name == "Hall 4")
    #expect(AVAudioUnitReverbPreset(rawValue: 5)?.name == "Plate")
    #expect(AVAudioUnitReverbPreset(rawValue: 6)?.name == "Chamber 1")
    #expect(AVAudioUnitReverbPreset(rawValue: 7)?.name == "Chamber 2")
    #expect(AVAudioUnitReverbPreset(rawValue: 8)?.name == "Cathedral")
    #expect(AVAudioUnitReverbPreset(rawValue: 9)?.name == "Room 4")
    #expect(AVAudioUnitReverbPreset(rawValue: 10)?.name == "Hall 2")
    #expect(AVAudioUnitReverbPreset(rawValue: 11)?.name == "Hall 3")
    #expect(AVAudioUnitReverbPreset(rawValue: 12)?.name == "Hall 5")
  }
}

