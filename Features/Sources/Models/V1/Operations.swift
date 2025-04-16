import Dependencies
import GRDB

public enum Operations {

  public static func soundFontIds(for tag: Tag.ID) -> [SoundFont.ID] {
    @Dependency(\.defaultDatabase) var database
    return (try? database.read {
      // FIX: do map in SQL
      try TaggedSoundFont.fetchAll($0).map { $0.soundFontId }
    }) ?? []
  }
  
  public static func tagIds(for soundFont: SoundFont.ID) -> [Tag.ID] {
    @Dependency(\.defaultDatabase) var database
    return (try? database.read {
      // FIX: do map in SQL
      try TaggedSoundFont.fetchAll($0).map { $0.tagId }
    }) ?? []
  }
  
  public static func tagSoundFont(_ tagId: Tag.ID, soundFontId: SoundFont.ID) throws -> TaggedSoundFont {
    @Dependency(\.defaultDatabase) var database
    return try database.write { try TaggedSoundFont(soundFontId: soundFontId, tagId: tagId).insertAndFetch($0) }
  }
  
  public static func untagSoundFont(_ tagId: Tag.ID, soundFontId: SoundFont.ID) throws {
    if tagId.isUbiquitous { throw ModelError.untaggingUbiquitous }
    @Dependency(\.defaultDatabase) var database
    let result = try database.write {
      try TaggedSoundFont.deleteOne($0, key: ["soundFontId": soundFontId, "tagId": tagId])
    }
    if !result {
      throw ModelError.notTagged
    }
  }

  public static func deleteTag(_ tagId: Tag.ID) -> Bool {
    if tagId.isUbiquitous { return false }
    @Dependency(\.defaultDatabase) var database
    return (try? database.write { try Tag.deleteOne($0, id: tagId) }) ?? false
  }
}
