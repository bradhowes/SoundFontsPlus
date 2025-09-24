import Dependencies
import Foundation
import Sharing
import SQLiteData
import Testing

@testable import SoundFontsPlus

extension BaseTestSuite {
  @MainActor
  struct PresetTests {}
}

extension BaseTestSuite.PresetTests {

  @MainActor
  func setup() async throws -> [Preset] {
    @Shared(.activeState) var activeState
    $activeState.withLock {
      $0.activeSoundFontId = 1
      $0.activePresetId = 1
    }
    return Operations.presets
  }

  @Test func soundFontName() async throws {
    let presets = try await setup()
    #expect(presets[123].soundFontName == "Fluid R3")
  }

  @Test func with() async throws {
    let presets = try await setup()
    let preset = Preset.with(id: 1)
    #expect(presets[0] == preset)
  }

  @Test func uniqueName() async throws {
    let presets = try await setup()
    #expect(presets[12].uniqueName == "Marimba copy")
    let clone1 = presets[12].clone()
    _ = presets[12].clone()
    #expect(presets[12].uniqueName == "Marimba copy 2")
    withDatabaseWriter { db in
      try Preset.delete()
        .where { $0.id.eq(clone1!.id) }
        .execute(db)
    }
    #expect(presets[12].uniqueName == "Marimba copy")
    _ = presets[12].clone()
    #expect(presets[12].uniqueName == "Marimba copy 2")
  }

  @Test func clone() async throws {
    let presets = try await setup()

    let clone1 = presets[12].clone()
    #expect(clone1 != nil)
    #expect(clone1?.audioConfig == nil)
    #expect(clone1?.delayConfig == nil)
    #expect(clone1?.reverbConfig == nil)

    AudioConfig.save(config: presets[12].audioConfigDraft)
    DelayConfig.save(config: presets[12].delayConfigDraft)
    ReverbConfig.save(config: presets[12].reverbConfigDraft)

    let clone2 = presets[12].clone()
    #expect(clone2 != nil)
    #expect(clone2?.audioConfig != nil)
    #expect(clone2?.delayConfig != nil)
    #expect(clone2?.reverbConfig != nil)
  }

  @Test func toggleVisibility() async throws {
    var presets = try await setup()
    var preset = presets[0]
    #expect(preset.kind == .preset)
    #expect(preset.displayName == "Yamaha Grand Piano")
    #expect(presets.count == 189)
    preset.toggleVisibility()

    presets = withDatabaseReader { db in try Preset.all.fetchAll(db) } ?? []
    presets = Operations.presets
    #expect(presets[0].displayName == "Bright Yamaha Grand")
    #expect(presets.count == 188)
    preset.toggleVisibility()

    presets = withDatabaseReader { db in try Preset.all.fetchAll(db) } ?? []
    presets = Operations.presets
    #expect(presets[0].displayName == "Yamaha Grand Piano")
    #expect(presets.count == 189)
  }
}
