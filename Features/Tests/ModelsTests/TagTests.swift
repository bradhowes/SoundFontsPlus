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
struct TagTests {

  @Test
  func migration() async throws {
    @FetchAll(Tag.queryBase) var tags
    try await $tags.load()

    #expect(tags.count == Tag.Ubiquitous.allCases.count)

    @FetchAll(SoundFont.all) var soundFonts
    try await $soundFonts.load()
    #expect(soundFonts.count == 4)

    @FetchAll(TaggedSoundFont.all) var taggedSoundFonts
    try await $taggedSoundFonts.load()
    #expect(taggedSoundFonts.count == 10)

    @FetchAll(Preset.all) var presets
    try await $presets.load()
    #expect(presets.count == 12)
  }

  @Test
  func tagged() async throws {
    @FetchAll(Tag.queryBase) var tags
    try await $tags.load()

    #expect(tags[0].soundFonts.count == 4)
    #expect(tags[1].soundFonts.count == 2)
    #expect(tags[2].soundFonts.count == 2)
    #expect(tags[3].soundFonts.count == 1)
    #expect(tags[4].soundFonts.count == 1)
  }

  @Test
  func create() async throws {
    @FetchAll(Tag.queryBase) var tags
    let displayName = "new tag"
    let tag = try Tag.make(displayName: displayName)
    #expect(tag.displayName == displayName)
    #expect(tag.isUserDefined)
    #expect(!tag.isUbiquitous)
    try await $tags.load()
    #expect(tags.count == Tag.Ubiquitous.allCases.count + 1)
  }

  @Test
  func deletingUbiquitous() async throws {
    @FetchAll(Tag.queryBase) var tags
    try await $tags.load()
    for each in Tag.Ubiquitous.allCases {
      #expect(throws: ModelError.deleteUbiquitous(name: each.displayName!)) {
        try tags[Int(each.id.rawValue * -1) - 1].delete()
      }
    }
  }

  @Test
  func delete() async throws {
    @FetchAll(Tag.queryBase) var tags
    let displayName = "tag to delete"
    let tag = try Tag.make(displayName: displayName)
    try await $tags.load()
    #expect(tags.count == Tag.Ubiquitous.allCases.count + 1)
    try tag.delete()
    try await $tags.load()
    #expect(tags.count == Tag.Ubiquitous.allCases.count)
    #expect(!tags.map(\.id).contains(tag.id))
  }

  @Test
  func renameUbiquitous() async throws {
    @FetchAll(Tag.queryBase) var tags
    try await $tags.load()
    for each in Tag.Ubiquitous.allCases {
      #expect(throws: ModelError.renameUbiquitous(name: each.displayName!)) {
        try tags[Int(each.id.rawValue * -1) - 1].rename(new: "nope")
      }
    }
  }

  @Test
  func renameToBlank() async throws {
    @FetchAll(Tag.queryBase) var tags
    let displayName = "tag to rename"
    let tag = try Tag.make(displayName: displayName)
    try await $tags.load()
    #expect(tags.count == Tag.Ubiquitous.allCases.count + 1)

    #expect(throws: ModelError.emptyTagName) {
      try tag.rename(new: "")
    }

    #expect(throws: ModelError.emptyTagName) {
      try tag.rename(new: "   ")
    }
  }

  @Test
  func rename() async throws {
    @FetchAll(Tag.queryBase) var tags
    let displayName = "tag to rename"
    let tag = try Tag.make(displayName: displayName)
    try await $tags.load()
    #expect(tags.count == Tag.Ubiquitous.allCases.count + 1)

    try tag.rename(new: "another name")
    try await $tags.load()
    #expect(tags.last!.displayName == "another name")
  }

  @Test
  func createWithInvalidName() async throws {
    @FetchAll(Tag.queryBase) var tags
    #expect(throws: ModelError.emptyTagName) {
      try Tag.make(displayName: "")
    }
    #expect(throws: ModelError.emptyTagName) {
      try Tag.make(displayName: "   ")
    }
  }

  @Test
  func createWithExistingName() async throws {
    for each in Tag.Ubiquitous.allCases {
      let newTag = try Tag.make(displayName: each.displayName!)
      #expect(newTag.displayName == each.displayName! + " 1")
    }

    for each in Tag.Ubiquitous.allCases {
      let newTag = try Tag.make(displayName: each.displayName!)
      #expect(newTag.displayName == each.displayName! + " 2")
    }
  }

  @Test
  func reorder() async throws {
    @FetchAll(Tag.queryBase) var tags
    try await $tags.load()
    try Tag.reorder(tagIds: [tags[4], tags[1], tags[0], tags[3], tags[2]].map(\.id))
    try await $tags.load()
    #expect(tags.count == 5)
    #expect(tags.map(\.displayName) == [
      Tag.Ubiquitous.external.displayName,
      Tag.Ubiquitous.builtIn.displayName,
      Tag.Ubiquitous.all.displayName,
      Tag.Ubiquitous.device.displayName,
      Tag.Ubiquitous.added.displayName
    ])
  }

  @Test
  func soundFontIdsForTag() async throws {
    #expect(Tag.soundFontIds(for: Tag.Ubiquitous.all.id) == [1, 2, 3, 4])
    #expect(Tag.soundFontIds(for: Tag.Ubiquitous.builtIn.id) == [1, 2])
    #expect(Tag.soundFontIds(for: Tag.Ubiquitous.added.id) == [3, 4])
    #expect(Tag.soundFontIds(for: Tag.Ubiquitous.external.id) == [4])
  }
}
