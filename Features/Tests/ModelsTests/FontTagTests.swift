// Copyright © 2025 Brad Howes. All rights reserved.

import Dependencies
import Foundation
import SQLiteData
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
struct FontTagTests {

  @Test
  func migration() async throws {
    @FetchAll(FontTag.tagsQuery) var tags
    try await $tags.load()

    #expect(tags.count == FontTag.Ubiquitous.allCases.count)

    @FetchAll(SoundFont.all) var soundFonts
    try await $soundFonts.load()
    #expect(soundFonts.count == 2)

    @FetchAll(TaggedSoundFont.all) var taggedSoundFonts
    try await $taggedSoundFonts.load()
    #expect(taggedSoundFonts.count == 4)

    @FetchAll(Preset.all) var presets
    try await $presets.load()
    #expect(presets.count == 4)
  }

  @Test
  func tagged() async throws {
    @FetchAll(FontTag.tagsQuery) var tags
    try await $tags.load()

    #expect(tags[0].soundFonts.count == 2)
    #expect(tags[1].soundFonts.count == 2)
    #expect(tags[2].soundFonts.isEmpty)
    #expect(tags[3].soundFonts.isEmpty)
  }

  @Test
  func create() async throws {
    @FetchAll(FontTag.tagsQuery) var tags
    let displayName = "new tag"
    let tag = try FontTag.make(displayName: displayName)
    #expect(tag.displayName == displayName)
    #expect(tag.isUserDefined)
    #expect(!tag.isUbiquitous)
    try await $tags.load()
    #expect(tags.count == FontTag.Ubiquitous.allCases.count + 1)
  }

  @Test
  func deletingUbiquitous() async throws {
    @FetchAll(FontTag.tagsQuery) var tags
    try await $tags.load()
    for each in FontTag.Ubiquitous.allCases {
      #expect(throws: ModelError.deleteUbiquitous(name: each.displayName)) {
        try tags[Int(each.id.rawValue - Int64(1))].delete()
      }
    }
  }

  @Test
  func delete() async throws {
    @FetchAll(FontTag.tagsQuery) var tags
    let displayName = "tag to delete"
    let tag = try FontTag.make(displayName: displayName)
    try await $tags.load()
    #expect(tags.count == FontTag.Ubiquitous.allCases.count + 1)
    try tag.delete()
    try await $tags.load()
    #expect(tags.count == FontTag.Ubiquitous.allCases.count)
    #expect(!tags.map(\.id).contains(tag.id))
  }

  @Test
  func renameUbiquitous() async throws {
    @FetchAll(FontTag.tagsQuery) var tags
    try await $tags.load()
    for each in FontTag.Ubiquitous.allCases {
      #expect(throws: ModelError.renameUbiquitous(name: each.displayName)) {
        try tags[Int(each.id.rawValue - Int64(1))].rename(new: "nope")
      }
    }
  }

  @Test
  func renameToBlank() async throws {
    @FetchAll(FontTag.tagsQuery) var tags
    let displayName = "tag to rename"
    let tag = try FontTag.make(displayName: displayName)
    try await $tags.load()
    #expect(tags.count == FontTag.Ubiquitous.allCases.count + 1)

    #expect(throws: ModelError.emptyTagName) {
      try tag.rename(new: "")
    }

    #expect(throws: ModelError.emptyTagName) {
      try tag.rename(new: "   ")
    }
  }

  @Test
  func rename() async throws {
    @FetchAll(FontTag.tagsQuery) var tags
    let displayName = "tag to rename"
    let tag = try FontTag.make(displayName: displayName)
    try await $tags.load()
    #expect(tags.count == FontTag.Ubiquitous.allCases.count + 1)

    try tag.rename(new: "another name")
    try await $tags.load()
    // swiftlint:disable:next force_unwrapping
    #expect(tags.last!.displayName == "another name")
  }

  @Test
  func createWithInvalidName() async throws {
    @FetchAll(FontTag.tagsQuery) var tags
    #expect(throws: ModelError.emptyTagName) {
      try FontTag.make(displayName: "")
    }
    #expect(throws: ModelError.emptyTagName) {
      try FontTag.make(displayName: "   ")
    }
  }

  @Test
  func createWithExistingName() async throws {
    for each in FontTag.Ubiquitous.allCases {
      let newTag = try FontTag.make(displayName: each.displayName)
      #expect(newTag.displayName == each.displayName + " 1")
    }

    for each in FontTag.Ubiquitous.allCases {
      let newTag = try FontTag.make(displayName: each.displayName)
      #expect(newTag.displayName == each.displayName + " 2")
    }
  }

  @Test
  func reorder() async throws {
    @FetchAll(FontTag.tagsQuery) var tags
    try await $tags.load()
    try FontTag.reorder(tagIds: [tags[1], tags[0], tags[3], tags[2]].map(\.id))
    try await $tags.load()
    #expect(tags.count == 4)
    #expect(tags.map(\.displayName) == [
      FontTag.Ubiquitous.builtIn.displayName,
      FontTag.Ubiquitous.all.displayName,
      FontTag.Ubiquitous.external.displayName,
      FontTag.Ubiquitous.added.displayName
    ])
  }
}
