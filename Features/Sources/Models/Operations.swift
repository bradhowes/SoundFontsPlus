// Copyright © 2025 Brad Howes. All rights reserved.

import BaseSupport
import Dependencies
import Sharing
import SQLiteData

public enum Operations {

  /**
   Obtain the loading info for a given preset ID. Used when directing the synth to begin using the preset.

   - parameter id: the preset to query for
   - returns: the optional `PresetLoadingInfo` for the preset
   */
  public static func presetLoadingInfo(id: Preset.ID) -> PresetLoadingInfo? {
    withDatabaseReader {
      try PresetLoadingInfo.query(for: id).fetchOne($0)
    } ?? nil
  }

  public static func soundFontIds(for tagId: Tag.ID) -> [SoundFont.ID] {
    (withDatabaseReader { try SoundFontInfo.query(for: tagId).fetchAll($0) } ?? []).map(\.id)
  }

  public static func tagSoundFont(_ tagId: Tag.ID, soundFontId: SoundFont.ID) {
    guard !tagId.isUbiquitous else { return }
    @Dependency(\.defaultDatabase) var database

    let existing = database.withReader { db in
      try TaggedSoundFont
        .where { $0.soundFontId.eq(soundFontId) }
        .where { $0.tagId.eq(tagId) }
        .fetchCount(db)
    } ?? 0

    guard existing == 0 else { return }
    database.withWriter { db in
      try TaggedSoundFont.insert {
        .init(soundFontId: soundFontId, tagId: tagId)
      }
      .execute(db)
    }
  }

  public static func untagSoundFont(_ tagId: Tag.ID, soundFontId: SoundFont.ID) {
    guard !tagId.isUbiquitous else { return }
    withDatabaseWriter { db in
      try TaggedSoundFont.all
        .delete()
        .where { $0.soundFontId.eq(soundFontId) && $0.tagId.eq(tagId) }
        .execute(db)
    }
  }
}

private let log: Logger = .init(category: "Operations")
