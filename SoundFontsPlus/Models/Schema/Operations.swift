// Copyright © 2025 Brad Howes. All rights reserved.

import Dependencies
import SharingGRDB

public enum Operations {

  public static var presetsQuery: Where<Preset> {
    @Shared(.showOnlyFavorites) var showOnlyFavorites
    let soundFontId = Preset.source ?? -1
    let query = Preset
      .all
      .where { $0.soundFontId.eq(soundFontId) }
    if showOnlyFavorites {
      return query
        .where { $0.kind.eq(Preset.Kind.favorite) }
    } else {
      return query
        .where { $0.kind.eq(Preset.Kind.preset) || $0.kind.eq(Preset.Kind.favorite) }
    }
  }

  public static var presets: [Preset] {
    @Shared(.favoritesOnTop) var favoritesOnTop
    let query = favoritesOnTop
    ? presetsQuery
      .order { $0.kind.desc() }
      .order(by: \.index)
    : presetsQuery
      .order(by: \.index)
      .order(by: \.kind)
      .order(by: \.displayName)
    @Dependency(\.defaultDatabase) var database
    return (try? database.read { try query.fetchAll($0) }) ?? []
  }

  public static var activePresetLoadingInfo: PresetLoadingInfo? {
    @Dependency(\.defaultDatabase) var database
    return (try? database.read { try PresetLoadingInfo.query.fetchOne($0) })
  }

  public static var allPresets: [Preset] {
    guard let soundFontId = Preset.source else { return [] }
    let query = Preset
      .all
      .where { $0.soundFontId.eq(soundFontId) }
      .where { $0.kind.eq(Preset.Kind.preset) || $0.kind.eq(Preset.Kind.hidden) }
      .order(by: \.index)
    @Dependency(\.defaultDatabase) var database
    return (try? database.read { try query.fetchAll($0) }) ?? []
  }

  public static func soundFontIds(for tagId: FontTag.ID) -> [SoundFont.ID] {
    let query = TaggedSoundFont.select { $0.soundFontId }.where { $0.tagId.eq(tagId) }
    @Dependency(\.defaultDatabase) var database
    return (try? database.read { try query.fetchAll($0) }) ?? []
  }

  public static func tagIds(for soundFontId: SoundFont.ID) -> [FontTag.ID] {
    let query = TaggedSoundFont.select { $0.tagId }.where { $0.soundFontId.eq(soundFontId) }
    @Dependency(\.defaultDatabase) var database
    return (try? database.read { try query.fetchAll($0) }) ?? []
  }

  public static func tagSoundFont(_ tagId: FontTag.ID, soundFontId: SoundFont.ID) {
    if tagId.isUbiquitous { return }
    let query = TaggedSoundFont.insert {
      .init(soundFontId: soundFontId, tagId: tagId)
    }
    @Dependency(\.defaultDatabase) var database
    try? database.write { try query.execute($0) }
  }

  public static func untagSoundFont(_ tagId: FontTag.ID, soundFontId: SoundFont.ID) {
    if tagId.isUbiquitous { return }
    let query = TaggedSoundFont.all.delete().where { $0.soundFontId.eq(soundFontId) && $0.tagId.eq(tagId) }
    @Dependency(\.defaultDatabase) var database
    try? database.write { try query.execute($0) }
  }

  public static func deleteTag(_ tagId: FontTag.ID) {
    if tagId.isUbiquitous { return }
    let query = FontTag.find(tagId).delete()
    @Dependency(\.defaultDatabase) var database
    try? database.write { try query.execute($0); }
  }

  public static var soundFontInfosQuery: Select<SoundFontInfo.Columns.QueryValue, TaggedSoundFont, SoundFont> {
    @Shared(.activeState) var activeState
    return TaggedSoundFont
      .join(SoundFont.all) {
        $0.tagId.eq(activeState.activeTagId ?? FontTag.Ubiquitous.all.id) && $0.soundFontId.eq($1.id)
      }
      .select {
        SoundFontInfo.Columns(id: $1.id, displayName: $1.displayName, kind: $1.kind, location: $1.location)
      }
  }

  public static var tagInfosQuery: Select<TagInfo.Columns.QueryValue, FontTag, TaggedSoundFont?> {
    FontTag
      .group(by: \.id)
      .order(by: \.ordering)
      .leftJoin(TaggedSoundFont.all) {
        $0.id.eq($1.tagId)
      }.select {
        TagInfo.Columns(id: $0.id, displayName: $0.displayName, soundFontsCount: $1.soundFontId.count())
      }
  }

  public static var tagsQuery: Select<(), FontTag, ()> {
    FontTag
      .order(by: \.ordering)
  }

  public static var tags: [FontTag] {
    @Dependency(\.defaultDatabase) var database
    return (try? database.read { try tagsQuery.fetchAll($0) }) ?? []
  }
}
