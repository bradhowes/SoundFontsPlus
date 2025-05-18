//import Dependencies
//import GRDB
//import Sharing
//
//public enum Operations {
//
//  public static func presetSource() -> SoundFont.ID? {
//    @Shared(.activeState) var activeState
//    return activeState.selectedSoundFontId ?? activeState.activeSoundFontId
//  }
//
//  public static func activePresetName() -> String {
//    @Shared(.activeState) var activeState
//    if let presetId = activeState.activePresetId {
//      @Dependency(\.defaultDatabase) var database
//      if let entry = try? database.read({ try Preset.fetchOne($0, id: presetId) }) {
//        return entry.displayName
//      }
//    }
//    return "—"
//  }
//
//  public static func preset(_ presetId: Preset.ID) -> Preset? {
//    @Dependency(\.defaultDatabase) var database
//    return try? database.read { try Preset.fetchOne($0, key: presetId) }
//  }
//
//  public static func presets() -> [Preset] {
//    guard let soundFontId = presetSource() else { return [] }
//    @Dependency(\.defaultDatabase) var database
//    return (try? database.read {
//      guard let soundFont = try SoundFont.fetchOne($0, key: soundFontId) else { return [] }
//      return try soundFont.visiblePresetsQuery.fetchAll($0)
//    }) ?? []
//  }
//
//  public static func allPresets() -> [Preset] {
//    guard let soundFontId = presetSource() else { return [] }
//    @Dependency(\.defaultDatabase) var database
//    return (try? database.read {
//      guard let soundFont = try SoundFont.fetchOne($0, key: soundFontId) else { return [] }
//      return try soundFont.allPresetsQuery.fetchAll($0)
//    }) ?? []
//  }
//
//  public static func soundFontIds(for tag: Tag.ID) -> [SoundFont.ID] {
//    @Dependency(\.defaultDatabase) var database
//    return (try? database.read {
//      // FIX: do map in SQL
//      try TaggedSoundFont.fetchAll($0).map { $0.soundFontId }
//    }) ?? []
//  }
//  
//  public static func tagIds(for soundFont: SoundFont.ID) -> [Tag.ID] {
//    @Dependency(\.defaultDatabase) var database
//    return (try? database.read {
//      // FIX: do map in SQL
//      try TaggedSoundFont.fetchAll($0).map { $0.tagId }
//    }) ?? []
//  }
//  
//  public static func tagSoundFont(_ tagId: Tag.ID, soundFontId: SoundFont.ID) -> TaggedSoundFont? {
//    @Dependency(\.defaultDatabase) var database
//    if tagId.isUbiquitous { return nil }
//    return try? database.write { try TaggedSoundFont(soundFontId: soundFontId, tagId: tagId).insertAndFetch($0) }
//  }
//  
//  public static func untagSoundFont(_ tagId: Tag.ID, soundFontId: SoundFont.ID) -> Bool {
//    if tagId.isUbiquitous { return false }
//    @Dependency(\.defaultDatabase) var database
//    return (try? database.write {
//      try TaggedSoundFont.deleteOne($0, key: ["soundFontId": soundFontId, "tagId": tagId])
//    }) ?? false
//  }
//
//  public static func deleteTag(_ tagId: Tag.ID) -> Bool {
//    if tagId.isUbiquitous { return false }
//    @Dependency(\.defaultDatabase) var database
//    return (try? database.write { try Tag.deleteOne($0, id: tagId) }) ?? false
//  }
//
//  public static func updateTags(_ tagsInfo: [(Tag.ID, String)]) -> Bool {
//    @Dependency(\.defaultDatabase) var database
//
//    var tags = Dictionary(uniqueKeysWithValues: Tag.ordered.map { ($0.id, $0) })
//    for (index, tagInfo) in tagsInfo.enumerated() {
//      let newName = tagInfo.1.trimmingCharacters(in: .whitespaces)
//      if !newName.isEmpty {
//        tags[tagInfo.0]?.name = newName
//      }
//      tags[tagInfo.0]?.ordering = index
//    }
//
//    return (try? database.write {
//      for (_, value) in tags {
//        try value.update($0)
//      }
//      return true
//    }) ?? false
//  }
//}
