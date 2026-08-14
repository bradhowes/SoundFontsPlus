// Copyright © 2026 Brad Howes. All rights reserved.

import BaseSupport
import DependenciesTestSupport
import Foundation
import SQLiteData
import Tagged
import Testing
import TestSupport

@testable import Models

@Suite(
  .dependencies {
    $0.defaultDatabase = TestSupport.testDatabase(seeder: TestSupport.addMockPresets)
  },
)
@MainActor
struct PresetTests {

  @MainActor
  func setup() async throws -> [Preset] {
    let presets = withDatabaseReader { try Preset.all.fetchAll($0) } ?? []
    return presets
  }

  @Test
  func cloneFavoriteClonesConfigsAndDeleteCascades() async throws {
    let presets = try await setup()
    let preset = presets[0]

    var audioConfig = preset.audioConfigDraft
    audioConfig.gain = 10.5
    audioConfig.keyboardLowestNoteEnabled = true
    AudioConfig.save(config: audioConfig)
    audioConfig = preset.audioConfigDraft
    #expect(audioConfig.gain == 10.5)

    var delayConfig = preset.delayConfigDraft
    delayConfig.enabled = true
    delayConfig.wetDryMix = 0.7
    DelayConfig.save(config: delayConfig)
    DelayConfig.save(config: delayConfig)
    delayConfig = preset.delayConfigDraft
    #expect(delayConfig.wetDryMix == 0.7)

    var reverbConfig = preset.reverbConfigDraft
    reverbConfig.enabled = true
    reverbConfig.wetDryMix = 0.8
    ReverbConfig.save(config: reverbConfig)
    reverbConfig = preset.reverbConfigDraft
    #expect(reverbConfig.wetDryMix == 0.8)

    PresetConfig.save(config: PresetConfig.Draft(presetId: preset.id, generatorId: 123, value: 123.45))
    PresetConfig.save(config: PresetConfig.Draft(presetId: preset.id, generatorId: 124, value: 124.67))

    let clone = try #require(preset.cloneFavorite())
    #expect(clone.id != preset.id)

    #expect(AudioConfig.with(presetId: clone.id) != nil)
    #expect(DelayConfig.with(presetId: clone.id) != nil)
    #expect(ReverbConfig.with(presetId: clone.id) != nil)
    #expect(PresetConfig.with(presetId: clone.id).count == 2)

    withDatabaseWriter { db in
      try Preset.all
        .where { $0.id.eq(clone.id) }
        .delete()
        .execute(db)
    }

    #expect(AudioConfig.with(presetId: clone.id) == nil)
    #expect(DelayConfig.with(presetId: clone.id) == nil)
    #expect(ReverbConfig.with(presetId: clone.id) == nil)
    #expect(PresetConfig.with(presetId: clone.id).isEmpty)
  }

  @Test
  func uniqueName() async throws {
    let presets = try await setup()
    let preset = presets[0]
    #expect(preset.uniqueName != preset.displayName)

    let clone1 = try #require(preset.cloneFavorite())
    let clone2 = try #require(clone1.cloneFavorite())
    let clone3 = try #require(clone2.cloneFavorite())
    let clone4 = try #require(preset.cloneFavorite())

    let names: Set<String> = [preset.uniqueName, clone1.uniqueName, clone2.uniqueName, clone3.uniqueName, clone4.uniqueName]
    #expect(names.count == 5)
  }
}
