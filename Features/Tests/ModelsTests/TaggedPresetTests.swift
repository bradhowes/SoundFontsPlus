// Copyright © 2025 Brad Howes. All rights reserved.

import DependenciesTestSupport
import Foundation
import SQLiteData
import Tagged
import Testing
import TestSupport

@testable import Models

@Suite(
  .dependencies {
    $0.defaultDatabase = TestSupport.testDatabase()
  },
  //  .snapshots(record: .failed)
)
@MainActor
struct TaggedPresetTests {

  @Test
  func link() async throws {
    let preset = Preset.with(id: 1)!
    let displayName = "tag"
    let tag = try PresetTag.make(displayName: displayName)
    #expect(preset.tags.isEmpty)
    TaggedPreset.link(presetId: preset.id, to: tag.id)
    #expect(preset.tags.count == 1)
    TaggedPreset.link(presetId: preset.id, to: tag.id)
    #expect(preset.tags.count == 1)
  }

  @Test
  func unlink() async throws {
    let preset = Preset.with(id: 1)!
    let displayName = "tag"
    let tag1 = try PresetTag.make(displayName: displayName)
    let tag2 = try PresetTag.make(displayName: displayName)

    TaggedPreset.link(presetId: preset.id, to: tag1.id)
    TaggedPreset.link(presetId: preset.id, to: tag2.id)

    #expect(preset.tags.count == 2)

    TaggedPreset.unlink(presetId: preset.id, from: tag1.id)
    #expect(preset.tags.count == 1)
    TaggedPreset.unlink(presetId: preset.id, from: tag2.id)
    #expect(preset.tags.isEmpty)
    TaggedPreset.unlink(presetId: preset.id, from: tag2.id)
  }

  @Test
  func presetDeletionCascades() async throws {
    let preset = Preset.with(id: 1)!
    let displayName = "tag"
    let tag = try PresetTag.make(displayName: displayName)
    TaggedPreset.link(presetId: preset.id, to: tag.id)
    TaggedPreset.link(presetId: preset.id, to: tag.id)
    withDatabaseWriter { db in
      try Preset.all
        .where { $0.id.eq(preset.id) }
        .delete()
        .execute(db)
    }

    let tagged = withDatabaseReader { db in
      try TaggedPreset.all
        .where { $0.presetId.eq(preset.id) }
        .fetchAll(db)
    } ?? []
    #expect(tagged.isEmpty)
  }
}
