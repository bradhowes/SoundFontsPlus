// Copyright © 2025 Brad Howes. All rights reserved.

import BaseSupport
import Dependencies
import Sharing
import SQLiteData

public enum Operations {

  /// - returns: the SoundFont ID to use when querying for presets to show, either the active or the selected font.
  public static func currentPresetsSource() -> SoundFont.ID? {
    @Shared(.selectedSoundFontId) var selectedSoundFontId
    @Shared(.activeState) var activeState
    return selectedSoundFontId ?? activeState.activeSoundFontId
  }

  /**
   Obtain a query that returns the set of presets to show (unordered) for a given sound font ID. Honors the
   `showOnlyFavorites` setting.

   - parameter soundFontId: the sound font to query for
   - returns: a query showing the appropriate contents
   */
  public static func presetsQuery(for soundFontId: SoundFont.ID? = nil) -> Where<Preset> {
    @Shared(.showOnlyFavorites) var showOnlyFavorites
    return Preset.all.where { $0.soundFontId.eq(soundFontId ?? currentPresetsSource() ?? -1) } && (
      showOnlyFavorites
      ? .where { $0.kind.eq(Preset.Kind.favorite) }
      : .where { $0.kind.eq(Preset.Kind.preset) || $0.kind.eq(Preset.Kind.favorite) }
    )
  }

  /**
   Obtain a query that returns an ordered collection of presets to show for a given sound font ID. Honors the
   `favoritesOnTop` and `sortPresetsByName` settings which affect the ordering.

   - parameter soundFontId: the sound font to query for
   - returns: the select query
   */
  public static func orderedPresetsQuery(for soundFontId: SoundFont.ID? = nil) -> Select<(), Preset, ()> {
    @Shared(.favoritesOnTop) var favoritesOnTop
    @Shared(.sortPresetsByName) var sortPresetsByName
    let query = presetsQuery(for: soundFontId)
    if sortPresetsByName {
      return favoritesOnTop
      ? query
        .order { $0.kind.desc() }
        .order { $0.displayName }
      : query
        .order { $0.kind }
        .order { $0.displayName }
    } else {
      return favoritesOnTop
      ? query
        .order { $0.kind.desc() }
        .order { $0.index }
      : query
        .order { $0.index }
        .order { $0.kind }
        .order { $0.displayName }
    }
  }

  /**
   Execute a query to obtain the presets for a given sound font ID.

   - parameter soundFontId: the sound font to query for
   - returns: the collection of presets
   */
  public static func presets(for soundFontId: SoundFont.ID? = nil) -> [Preset] {
    withDatabaseReader {
      try orderedPresetsQuery(for: soundFontId).fetchAll($0)
    } ?? []
  }

  /**
   Obtain the collection of presets for a given sound font ID. Does not perform any filter of hidden presets, and is
   used when editing preset visibility.

   - parameter soundFontId: the sound font to query for
   - returns: the collection of presets
   */
  public static func allPresets(for soundFontId: SoundFont.ID?) -> [Preset] {
    guard let soundFontId = (soundFontId ?? currentPresetsSource()) else { return [] }
    let query = Preset
      .all
      .where { $0.soundFontId.eq(soundFontId) }
      .where { $0.kind.eq(Preset.Kind.preset) || $0.kind.eq(Preset.Kind.hidden) }
      .order(by: \.index)
    let results = withDatabaseReader { try query.fetchAll($0) } ?? []
    log.info("soundFontId: \(soundFontId) results: \(results)")
    return results
  }

  /**
   Obtain the loading info for a given preset ID. Used when directing the synth to begin using the preset.

   - parameter id: the preset to query for
   - returns: the optional `PresetLoadingInfo` for the preset
   */
  public static func presetLoadingInfo(id: Preset.ID? = nil) -> PresetLoadingInfo? {
    withDatabaseReader {
      try PresetLoadingInfo.query(for: id).fetchOne($0)
    } ?? nil
  }

  public static func presetAudioConfig(id: Preset.ID? = nil) -> AudioConfig? {
    @Shared(.activeState) var activeState
    return AudioConfig.with(presetId: id ?? activeState.activePresetId)
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
