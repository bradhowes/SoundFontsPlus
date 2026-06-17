// Copyright © 2026 Brad Howes. All rights reserved.

import AVFAudio.AVAudioSession
import DependenciesTestSupport
import Foundation
import Testing

@testable import Models

@Suite
struct PresetSourceTests {

  @Test
  func makeActive() throws {
    #expect(PresetSource.makeActive(nil) == nil)
    let ps = PresetSource.makeActive(SoundFont.ID(rawValue: 100))
    #expect(ps != nil)
    #expect(ps?.isActive == true)
  }

  @Test
  func isActive() throws {
    #expect(PresetSource.active(0).isActive == true)
    #expect(PresetSource.selected(0).isActive == false)
  }

  @Test
  func isSelected() throws {
    #expect(PresetSource.active(0).isSelected == false)
    #expect(PresetSource.selected(0).isSelected == true)
  }

  @Test
  func activated() throws {
    #expect(PresetSource.active(0).activated.id == 0)
    #expect(PresetSource.selected(0).activated == PresetSource.active(0))
    #expect(PresetSource.selected(0).activated != PresetSource.active(1))
  }
}
