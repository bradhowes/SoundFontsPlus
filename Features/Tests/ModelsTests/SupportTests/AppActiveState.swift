// Copyright © 2026 Brad Howes. All rights reserved.

import AudioToolbox.AudioUnitProperties
import DependenciesTestSupport
import Sharing
import SQLiteData
import Tagged
import TestSupport
import Testing

@testable import Models

@Suite(
  .dependencies {
    $0.defaultDatabase = TestSupport.testDatabase()
  }
)
struct AppActiveStateTests {

  @Test
  func liveValue() {
    @Shared(.appActiveStateValue) var activeStateValue = .init(
      activeSoundFontId: 1,
      activePresetId: 2,
      activeTagId: Tag.Ubiquitous.all.id
    )

    let aas = AppActiveState.liveValue
    #expect(aas.getActiveSoundFontId() == activeStateValue.activeSoundFontId)
    #expect(aas.getActivePresetId() == activeStateValue.activePresetId)
    #expect(aas.getActiveTagId() == activeStateValue.activeTagId)

    aas.setActiveSoundFontId(nil)
    #expect(aas.getActiveSoundFontId() == activeStateValue.activeSoundFontId)

    aas.setActivePresetId(nil)
    #expect(aas.getActivePresetId() == activeStateValue.activePresetId)

    aas.setActiveTagId(nil)
    #expect(aas.getActiveTagId() == activeStateValue.activeTagId)
  }

  @Test
  func previewValue() {
    @Shared(.tmpActiveStateValue) var activeStateValue = .init(
      activeSoundFontId: 1,
      activePresetId: 2,
      activeTagId: Tag.Ubiquitous.all.id
    )

    let aas = AppActiveState.previewValue
    #expect(aas.getActiveSoundFontId() == activeStateValue.activeSoundFontId)
    #expect(aas.getActivePresetId() == activeStateValue.activePresetId)
    #expect(aas.getActiveTagId() == activeStateValue.activeTagId)

    aas.setActiveSoundFontId(nil)
    #expect(aas.getActiveSoundFontId() == activeStateValue.activeSoundFontId)

    aas.setActivePresetId(nil)
    #expect(aas.getActivePresetId() == activeStateValue.activePresetId)

    aas.setActiveTagId(nil)
    #expect(aas.getActiveTagId() == activeStateValue.activeTagId)
  }

  @Test
  func testValue() {
    @Shared(.tmpActiveStateValue) var activeStateValue = .init(
      activeSoundFontId: 1,
      activePresetId: 2,
      activeTagId: Tag.Ubiquitous.all.id
    )

    let aas = AppActiveState.testValue
    #expect(aas.getActiveSoundFontId() == activeStateValue.activeSoundFontId)
    #expect(aas.getActivePresetId() == activeStateValue.activePresetId)
    #expect(aas.getActiveTagId() == activeStateValue.activeTagId)

    aas.setActiveSoundFontId(nil)
    #expect(aas.getActiveSoundFontId() == activeStateValue.activeSoundFontId)

    aas.setActivePresetId(nil)
    #expect(aas.getActivePresetId() == activeStateValue.activePresetId)

    aas.setActiveTagId(nil)
    #expect(aas.getActiveTagId() == activeStateValue.activeTagId)
  }

  @Test
  func appDefaultDefaultValue() {
    @Shared(.appActiveStateValue) var activeStateValue
    #expect(activeStateValue.activeSoundFontId == 1)
    #expect(activeStateValue.activePresetId == 1)
    #expect(activeStateValue.activeTagId == Tag.Ubiquitous.all.id)
  }

  @Test
  func tmpDefaultDefaultValue() {
    @Shared(.tmpActiveStateValue) var activeStateValue
    #expect(activeStateValue.activeSoundFontId == 1)
    #expect(activeStateValue.activePresetId == 1)
    #expect(activeStateValue.activeTagId == Tag.Ubiquitous.all.id)
  }

  @Test
  func defaultValue() {
    @Shared(.appActiveStateValue) var activeStateValue = .default
    #expect(activeStateValue.activeSoundFontId == 1)
    #expect(activeStateValue.activePresetId == 1)
    #expect(activeStateValue.activeTagId == Tag.Ubiquitous.all.id)
  }

  @Test
  func noneValue() {
    @Shared(.appActiveStateValue) var activeStateValue = .none
    #expect(activeStateValue.activeSoundFontId == nil)
    #expect(activeStateValue.activePresetId == nil)
    #expect(activeStateValue.activeTagId == nil)
  }
}
