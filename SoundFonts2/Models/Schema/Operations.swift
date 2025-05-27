// Copyright © 2025 Brad Howes. All rights reserved.

import Dependencies
import SharingGRDB

public enum Operations {

  public static var presets: [Preset] {
    guard let soundFontId = Preset.source else { return [] }
    let query = Preset.all.where { $0.soundFontId == soundFontId && $0.visible }.order(by: \.index)
    @Dependency(\.defaultDatabase) var database
    return (try? database.read { try query.fetchAll($0) }) ?? []
  }

  public static var allPresets: [Preset] {
    guard let soundFontId = Preset.source else { return [] }
    let query = Preset.all.where { $0.soundFontId == soundFontId }.order(by: \.index)
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

//  public static func updateTags(_ tagsInfo: [(Tag.ID, String)]) {
//    @Dependency(\.defaultDatabase) var database
//    for (ordering, (tagId, name)) in tagsInfo.enumerated() {
//      let newName = name.trimmingCharacters(in: .whitespaces)
//      let query = Tag
//        .find(tagId)
//        .update {
//          if tagId.isUserDefined && !newName.isEmpty {
//            $0.displayName = newName
//          }
//          $0.ordering = ordering
//        }
//      try? database.write { try query.execute($0) }
//    }
//  }

  public static func updateTags(_ tags: [Tag]) {
    @Dependency(\.defaultDatabase) var database
    let query = Tag.insert(or: .replace, tags)
    try? database.write { try query.execute($0) }
  }

  public static func setVisibility(of presetId: Preset.ID, to visible: Bool) {
    let query = Preset.find(presetId).update { $0.visible = visible }
    @Dependency(\.defaultDatabase) var database
    try? database.write { try query.execute($0) }
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
