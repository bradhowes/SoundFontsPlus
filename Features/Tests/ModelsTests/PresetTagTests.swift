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
    @FetchAll(PresetTag.all) var tags
    try await $tags.load()

    #expect(tags.isEmpty)

    @FetchAll(TaggedPreset.all) var taggedPresets
    try await $taggedPresets.load()
    #expect(taggedPresets.isEmpty)
  }

  @Test
  func create() async throws {
    @FetchAll(PresetTag.all) var tags
    let displayName = "tag"
    let tag = try PresetTag.make(displayName: displayName)
    #expect(tag.displayName == displayName)
    try await $tags.load()
    #expect(tags.count == 1)
  }

  @Test
  func delete() async throws {
    @FetchAll(PresetTag.all) var tags
    let displayName = "deleteMe"
    let tag = try PresetTag.make(displayName: displayName)
    try await $tags.load()
    #expect(tags.count == 1)
    try tag.delete()
    try await $tags.load()
    #expect(tags.isEmpty)
    #expect(!tags.map(\.id).contains(tag.id))
  }

  @Test
  func renameToBlank() async throws {
    @FetchAll(PresetTag.all) var tags
    let displayName = "renameMe"
    let tag = try PresetTag.make(displayName: displayName)
    try await $tags.load()
    #expect(tags.count == 1)

    #expect(throws: ModelError.emptyTagName) {
      try tag.rename(new: "")
    }

    #expect(throws: ModelError.emptyTagName) {
      try tag.rename(new: "   ")
    }
  }

  @Test
  func rename() async throws {
    @FetchAll(PresetTag.all) var tags
    let displayName = "renameMe"
    let tag = try PresetTag.make(displayName: displayName)
    try await $tags.load()
    #expect(tags.count == 1)

    try tag.rename(new: "another name")
    try await $tags.load()
    #expect(tags.last?.displayName == "another name")
  }

  @Test
  func createWithInvalidName() async throws {
    @FetchAll(PresetTag.all) var tags
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
  }
}
