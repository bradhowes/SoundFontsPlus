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
struct PresetTagTests {

  @Test
  func migration() async throws {
    #expect(PresetTag.all.isEmpty)
    let taggedPresets = withDatabaseReader { try TaggedPreset.all.fetchAll($0) } ?? []
    #expect(taggedPresets.isEmpty)
  }

  @Test
  func create() async throws {
    let displayName = "tag"
    let tag = try PresetTag.make(displayName: displayName)
    #expect(tag.displayName == displayName)
    #expect(PresetTag.all.count == 1)
  }

  @Test
  func delete() async throws {
    let displayName = "deleteMe"
    let tag = try PresetTag.make(displayName: displayName)
    #expect(PresetTag.all.count == 1)
    try tag.delete()
    #expect(PresetTag.all.isEmpty)
  }

  @Test
  func renameToBlank() async throws {
    let displayName = "renameMe"
    let tag = try PresetTag.make(displayName: displayName)
    #expect(PresetTag.all.count == 1)

    #expect(throws: ModelError.emptyTagName) {
      try tag.rename(new: "")
    }

    #expect(throws: ModelError.emptyTagName) {
      try tag.rename(new: "   ")
    }
  }

  @Test
  func rename() async throws {
    let displayName = "renameMe"
    let tag = try PresetTag.make(displayName: displayName)
    #expect(PresetTag.all.count == 1)

    try tag.rename(new: "another name")
    #expect(PresetTag.all.last?.displayName == "another name")
  }

  @Test
  func createWithInvalidName() async throws {
    #expect(throws: ModelError.emptyTagName) {
      try PresetTag.make(displayName: "")
    }
    #expect(throws: ModelError.emptyTagName) {
      try PresetTag.make(displayName: "   ")
    }
  }

  @Test
  func createWithExistingName() async throws {
    let tag = try PresetTag.make(displayName: "new")
    let newTag = try PresetTag.make(displayName: "new")
    #expect(newTag.displayName == tag.displayName + " 1")
    #expect(PresetTag.all.count == 2)
  }
}
