// Copyright © 2025 Brad Howes. All rights reserved.

import Dependencies
import Sharing
import SQLiteData

public enum Operations {

  public static func currentPresetsSource() -> SoundFont.ID? {
    @Shared(.selectedSoundFontId) var selectedSoundFontId
    @Shared(.activeState) var activeState
    return selectedSoundFontId ?? activeState.activeSoundFontId
  }

  public static func presetsQuery(for soundFontId: SoundFont.ID? = nil) -> Where<Preset> {
    @Shared(.showOnlyFavorites) var showOnlyFavorites
    let query = Preset
      .all
      .where { $0.soundFontId.eq(soundFontId ?? currentPresetsSource() ?? -1) }
    if showOnlyFavorites {
      return query
        .where { $0.kind.eq(Preset.Kind.favorite) }
    } else {
      return query
        .where { $0.kind.eq(Preset.Kind.preset) || $0.kind.eq(Preset.Kind.favorite) }
    }
  }

  public static func presets(for soundFontId: SoundFont.ID? = nil) -> [Preset] {
    @Shared(.favoritesOnTop) var favoritesOnTop
    @Shared(.sortPresetsByName) var sortPresetsByName
    let query: Select<(), Preset, ()>
    if sortPresetsByName {
      query = favoritesOnTop
      ? presetsQuery(for: soundFontId)
        .order { $0.kind.desc() }
        .order(by: \.displayName)
      : presetsQuery(for: soundFontId)
        .order(by: \.kind)
        .order(by: \.displayName)
    } else {
      query = favoritesOnTop
      ? presetsQuery(for: soundFontId)
        .order { $0.kind.desc() }
        .order(by: \.index)
      : presetsQuery(for: soundFontId)
        .order(by: \.index)
        .order(by: \.kind)
        .order(by: \.displayName)
    }
    return withDatabaseReader { try query.fetchAll($0) } ?? []
  }

  public static func presetLoadingInfo(id: Preset.ID? = nil) -> PresetLoadingInfo? {
    withDatabaseReader {
      try PresetLoadingInfo.query(for: id).fetchAll($0)
    }?.first
  }

  public static func presetAudioConfig(id: Preset.ID? = nil) -> AudioConfig? {
    @Shared(.activeState) var activeState
    return AudioConfig.with(presetId: id ?? activeState.activePresetId)
  }

  public static func allPresets(for soundFontId: SoundFont.ID?) -> [Preset] {
    guard let soundFontId = (soundFontId ?? currentPresetsSource()) else { return [] }
    let query = Preset
      .all
      .where { $0.soundFontId.eq(soundFontId) }
      .where { $0.kind.eq(Preset.Kind.preset) || $0.kind.eq(Preset.Kind.hidden) }
      .order(by: \.index)
    return withDatabaseReader { try query.fetchAll($0) } ?? []
  }

  public static func soundFontIds(for tagId: FontTag.ID) -> [SoundFont.ID] {
    let query = TaggedSoundFont.select { $0.soundFontId }.where { $0.tagId.eq(tagId) }
    return withDatabaseReader { try query.fetchAll($0) } ?? []
  }

  public static func tagIds(for soundFontId: SoundFont.ID) -> [FontTag.ID] {
    withDatabaseReader {
      try TaggedSoundFont.select { $0.tagId }
        .where { $0.soundFontId.eq(soundFontId) }
        .fetchAll($0)
    } ?? []
  }

  public static func tagSoundFont(_ tagId: FontTag.ID, soundFontId: SoundFont.ID) {
    guard !tagId.isUbiquitous else { return }
    let existing = tagIds(for: soundFontId)
    guard existing.first(where: {$0 == tagId}) == nil else { return }
    withDatabaseWriter { db in
      try TaggedSoundFont.insert {
        .init(soundFontId: soundFontId, tagId: tagId)
      }
      .execute(db)
    }
  }

  public static func untagSoundFont(_ tagId: FontTag.ID, soundFontId: SoundFont.ID) {
    guard !tagId.isUbiquitous else { return }
    withDatabaseWriter { db in
      try TaggedSoundFont.all
        .delete()
        .where { $0.soundFontId.eq(soundFontId) && $0.tagId.eq(tagId) }
        .execute(db)
    }
  }
}
