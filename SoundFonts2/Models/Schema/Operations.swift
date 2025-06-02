// Copyright © 2025 Brad Howes. All rights reserved.

import Dependencies
import SharingGRDB

public enum Operations {

  public static var presets: [Preset] {
    guard let soundFontId = Preset.source else { return [] }
    let query = Preset
      .all
      .where { $0.soundFontId.eq(soundFontId) }
      .where { $0.kind.eq(Preset.Kind.preset) || $0.kind.eq(Preset.Kind.favorite) }
      .order(by: \.index)
      .order(by: \.kind)
    @Dependency(\.defaultDatabase) var database
    return (try? database.read { try query.fetchAll($0) }) ?? []
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

  public static func soundFontIds(for tagId: Tag.ID) -> [SoundFont.ID] {
    let query = TaggedSoundFont.select { $0.soundFontId }.where { $0.tagId.eq(tagId) }
    @Dependency(\.defaultDatabase) var database
    return (try? database.read { try query.fetchAll($0) }) ?? []
  }
  
  public static func tagIds(for soundFontId: SoundFont.ID) -> [Tag.ID] {
    let query = TaggedSoundFont.select { $0.tagId }.where { $0.soundFontId.eq(soundFontId) }
    @Dependency(\.defaultDatabase) var database
    return (try? database.read { try query.fetchAll($0) }) ?? []
  }
  
  public static func tagSoundFont(_ tagId: Tag.ID, soundFontId: SoundFont.ID) {
    if tagId.isUbiquitous { return }
    let query = TaggedSoundFont.insert(.init(soundFontId: soundFontId, tagId: tagId))
    @Dependency(\.defaultDatabase) var database
    try? database.write { try query.execute($0) }
  }
  
  public static func untagSoundFont(_ tagId: Tag.ID, soundFontId: SoundFont.ID) {
    if tagId.isUbiquitous { return }
    let query = TaggedSoundFont.all.delete().where { $0.soundFontId.eq(soundFontId) && $0.tagId.eq(tagId) }
    @Dependency(\.defaultDatabase) var database
    try? database.write { try query.execute($0) }
  }

  public static func deleteTag(_ tagId: Tag.ID) {
    if tagId.isUbiquitous { return }
    let query = Tag.find(tagId).delete()
    @Dependency(\.defaultDatabase) var database
    try? database.write { try query.execute($0); }
  }

  public static func updateTags(_ tags: [Tag]) {
    @Dependency(\.defaultDatabase) var database
    withErrorReporting {
      try database.write { db in
        for tag in tags {
          try Tag.find(tag.id)
            .update {
              $0.displayName = tag.displayName
              $0.ordering = tag.ordering
            }
            .execute(db)
        }
      }
    }
  }

  public static var soundFontInfosQuery: Select<SoundFontInfo.Columns.QueryValue, TaggedSoundFont, SoundFont> {
    @Shared(.activeState) var activeState
    return TaggedSoundFont
      .join(SoundFont.all) {
        $0.tagId.eq(activeState.activeTagId ?? Tag.Ubiquitous.all.id) && $0.soundFontId.eq($1.id)
      }
      .select {
        SoundFontInfo.Columns(id: $1.id, displayName: $1.displayName, kind: $1.kind, location: $1.location)
      }
  }

  public static var tagInfosQuery: Select<TagInfo.Columns.QueryValue, Tag, TaggedSoundFont?> {
    Tag
      .group(by: \.id)
      .order(by: \.ordering)
      .leftJoin(TaggedSoundFont.all) {
        $0.id.eq($1.tagId)
      }.select {
        TagInfo.Columns(id: $0.id, displayName: $0.displayName, soundFontsCount: $1.soundFontId.count())
      }
  }

  public static var tagsQuery: Select<(), Tag, ()> {
    Tag
      .order(by: \.ordering)
  }

  public static var tags: [Tag] {
    @Dependency(\.defaultDatabase) var database
    return (try? database.read { try tagsQuery.fetchAll($0) }) ?? []
  }
}
