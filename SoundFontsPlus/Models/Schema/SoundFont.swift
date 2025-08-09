// Copyright © 2025 Brad Howes. All rights reserved.

import Dependencies
import Engine
import SharingGRDB
import Tagged

/**
 Definition of a soundfont table that holds various pieces of information regarding soundfont files.
 A SoundFont entry contains various meta data attributes loaded from a SF2 file. Most of these attributes are not
 necessary for app usage. The `SoundFontEditor` feature is the only one that reveals this meta data. Usually, the app
 works with `SoundFontInfo` rows which is a slimmer view into the SoundFont table.
 */
@Table
public struct SoundFont: Hashable, Identifiable, Sendable {
  public typealias ID = Tagged<Self, Int64>

  public let id: ID

  public enum Kind: String, CaseIterable, Sendable, QueryBindable {
    case builtin
    case installed
    case external
  }

  public var displayName: String

  public let kind: Kind
  public let location: Data

  public let originalName: String
  public let embeddedName: String
  public let embeddedComment: String
  public let embeddedAuthor: String
  public let embeddedCopyright: String

  public var notes: String

  public var isInstalled: Bool { kind == .installed }
  public var isExternal: Bool { kind == .external }
  public var isBuiltIn: Bool { kind == .builtin }
}

extension SoundFont {

  public static func insert(_ db: Database, sf2: SF2ResourceFileTag) {
    let log = Logger(category: "SoundFont.insert")
    withErrorReporting {
      let soundFontKind: SoundFontKind = .builtin(resource: sf2.url)
      let (kind, location) = try soundFontKind.data()
      let fileInfo = try soundFontKind.fileInfo()
      let insertSoundFontDraft = SoundFont.insert {
        SoundFont.Draft(
          displayName: sf2.name,
          kind: kind,
          location: location,
          originalName: sf2.name,
          embeddedName: String(fileInfo.embeddedName()),
          embeddedComment: String(fileInfo.embeddedComment()),
          embeddedAuthor: String(fileInfo.embeddedAuthor()),
          embeddedCopyright: String(fileInfo.embeddedCopyright()),
          notes: ""
        )
      }.returning(\.id)

      if let soundFontId = try insertSoundFontDraft.fetchOne(db) {
        log.info("soundFontId: \(soundFontId)")

        let taggedSoundFonts: [TaggedSoundFont] = soundFontKind.tagIds.map { tagId in
            .init(
              soundFontId: soundFontId,
              tagId: tagId
            )
        }

        try TaggedSoundFont.insert {
          taggedSoundFonts
        }.execute(db)

        // Insert presets in one shot
        let presets: [Preset.Draft] = (0..<fileInfo.size()).map { presetIndex in
          let presetInfo = fileInfo[presetIndex]
          let displayName = String(presetInfo.name())
          return .init(
            index: presetIndex,
            bank: Int(presetInfo.bank()),
            program: Int(presetInfo.program()),
            originalName: displayName,
            soundFontId: soundFontId,
            displayName: displayName,
            notes: "",
            kind: .preset
          )
        }
        try Preset.insert {
          presets
        }.execute(db)
      }
    }
  }

  public static func add(displayName: String, soundFontKind: SoundFontKind) throws {
    let (kind, location) = try soundFontKind.data()
    let fileInfo = try soundFontKind.fileInfo()
    let insertSoundFontDraft = SoundFont.insert {
      SoundFont.Draft(
        displayName: displayName,
        kind: kind,
        location: location,
        originalName: displayName,
        embeddedName: String(fileInfo.embeddedName()),
        embeddedComment: String(fileInfo.embeddedComment()),
        embeddedAuthor: String(fileInfo.embeddedAuthor()),
        embeddedCopyright: String(fileInfo.embeddedCopyright()),
        notes: ""
      )
    }.returning(\.id)

    @Dependency(\.defaultDatabase) var database
    try database.write { db in
      if let soundFontId = try insertSoundFontDraft.fetchOne(db) {

        // Insert tagging in one shot
        let taggedSoundFonts: [TaggedSoundFont] = soundFontKind.tagIds.map { tagId in
            .init(
              soundFontId: soundFontId,
              tagId: tagId
            )
        }
        try TaggedSoundFont.insert {
          taggedSoundFonts
        }.execute(db)

        // Insert presets in one shot
        let presets: [Preset.Draft] = (0..<fileInfo.size()).map { presetIndex in
          let presetInfo = fileInfo[presetIndex]
          let displayName = String(presetInfo.name())
          return .init(
            index: presetIndex,
            bank: Int(presetInfo.bank()),
            program: Int(presetInfo.program()),
            originalName: displayName,
            soundFontId: soundFontId,
            displayName: displayName,
            notes: "",
            kind: .preset,
          )
        }
        try Preset.insert {
          presets
        }.execute(db)
      }
    }
  }

  public static func delete(id: SoundFont.ID) {
    @Dependency(\.defaultDatabase) var database
    withErrorReporting {
      try database.write { db in
        try Self.delete().where({ $0.id == id }).execute(db)
      }
    }
  }
}

extension SoundFont {

  static func migrate(_ migrator: inout DatabaseMigrator) {
    migrator.registerMigration(Self.tableName) { db in
      try #sql(
      """
      CREATE TABLE "\(raw: Self.tableName)" (
        "id" INTEGER PRIMARY KEY AUTOINCREMENT,
        "displayName" TEXT NOT NULL,
        "kind" TEXT NOT NULL,
        "location" BLOB,
        "originalName" TEXT NOT NULL,
        "embeddedName" TEXT NOT NULL,
        "embeddedComment" TEXT NOT NULL,
        "embeddedAuthor" TEXT NOT NULL,
        "embeddedCopyright" TEXT NOT NULL,
        "notes" TEXT NOT NULL
      ) STRICT
      """
      )
      .execute(db)
    }
  }
}

extension SoundFont {

  public func source() throws -> SoundFontKind {
    try SoundFontKind(kind: kind, location: location)
  }

  public var sourceKind: String { (try? source())?.description ?? "N/A" }

  public var sourcePath: String { (try? source())?.path.absoluteString ?? "N/A" }

  public var tags: [FontTag] {
    let query = TaggedSoundFont
      .join(FontTag.all) {
        $0.tagId.eq($1.id) && $0.soundFontId.eq(self.id)
      }
      .select {
        $1
      }

    @Dependency(\.defaultDatabase) var database
    return (try? database.read { try query.fetchAll($0) }) ?? []
  }

  public var presets: [Preset] {
    let query = Preset.all
      .order(by: \.index)
      .where { $0.soundFontId.eq(self.id) }
      .where { $0.kind.neq(Preset.Kind.hidden) }

    @Dependency(\.defaultDatabase) var database
    return (try? database.read { try query.fetchAll($0) }) ?? []
  }

  public var allPresets: [Preset] {
    let query = Preset.all
      .order(by: \.index)
      .where { $0.soundFontId.eq(self.id) }
      .where { $0.kind.neq(Preset.Kind.favorite) }

    @Dependency(\.defaultDatabase) var database
    return (try? database.read { try query.fetchAll($0) }) ?? []
  }

  // swiftlint:disable:next large_tuple
  public var elementCounts: (presetCount: Int, favoriteCount: Int, hiddenCount: Int) {
    @Dependency(\.defaultDatabase) var database
    let found = try? database.read { db in
      try Preset.select {
        (
          $0.id.count(filter: $0.kind.eq(Preset.Kind.preset)),
          $0.id.count(filter: $0.kind.eq(Preset.Kind.favorite)),
          $0.id.count(filter: $0.kind.eq(Preset.Kind.hidden))
        )
      }
      .where { $0.soundFontId.eq(self.id) }
      .fetchAll(db)
    }
    return (found ?? [(presetCount: 0, favoriteCount: 0, hiddenCount: 0)])[0]
  }
}

extension SoundFont {

  // swiftlint:disable:next function_body_length
  public static func mock(
    _ db: Database,
    kind: Kind,
    name: String,
    presetNames: [String],
    tags: [String]
  ) throws {
    let tmp = try FileManager.default.newTemporaryURL()
    try FileManager.default.copyItem(
      at: SF2ResourceFileTag.rolandNicePiano.url,
      to: tmp
    )

    let soundFontKind: SoundFontKind = kind == .installed
    ? SoundFontKind.installed(file: tmp)
    : SoundFontKind.external(bookmark: .init(url: tmp, name: name))
    let (kind, location) = try soundFontKind.data()

    let insertSoundFontDraft = SoundFont.insert {
      SoundFont.Draft(
        displayName: name,
        kind: kind,
        location: location,
        originalName: name,
        embeddedName: name,
        embeddedComment: "comment",
        embeddedAuthor: "author",
        embeddedCopyright: "copyright",
        notes: ""
      )
    }.returning(\.id)

    if let soundFontId = try insertSoundFontDraft.fetchOne(db) {
      let taggedSoundFonts: [TaggedSoundFont] = soundFontKind.tagIds.map { tagId in
          .init(
            soundFontId: soundFontId,
            tagId: tagId
          )
      }
      try TaggedSoundFont.insert {
        taggedSoundFonts
      }.execute(db)

      let presets: [Preset.Draft] = presetNames.enumerated().map { indexedPresetName in
        let displayName = indexedPresetName.1
        return .init(
          index: indexedPresetName.0,
          bank: 0,
          program: indexedPresetName.0,
          originalName: displayName,
          soundFontId: soundFontId,
          displayName: displayName,
          notes: "",
          kind: .preset
        )
      }

      try Preset.insert {
        presets
      }.execute(db)

      for tagName in tags.enumerated() {
        let query = FontTag.insert {
          FontTag.Draft(
            displayName: tagName.1,
            ordering: tagName.0 + 5
          )
        }.returning(\.id)

        if let tagId = try query.fetchOne(db) {
          try TaggedSoundFont.insert {
            .init(
              soundFontId: soundFontId,
              tagId: tagId
            )
          }.execute(db)
        }
      }
    }
  }
}
