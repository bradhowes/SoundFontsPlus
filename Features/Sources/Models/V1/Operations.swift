import Dependencies
import GRDB

public enum Operations {

  public func soundFontIds(for tag: Tag.ID) -> [SoundFont.ID] {
    @Dependency(\.defaultDatabase) var database
    return (try? database.read {
      // FIX: do map in SQL
      try TaggedSoundFont.fetchAll($0).map { $0.soundFontId }
    }) ?? []
  }
  
  public func tagIds(for soundFont: SoundFont.ID) -> [Tag.ID] {
    @Dependency(\.defaultDatabase) var database
    return (try? database.read {
      // FIX: do map in SQL
      try TaggedSoundFont.fetchAll($0).map { $0.tagId }
    }) ?? []
  }
  
  public static func tagSoundFont(_ tagId: Tag.ID, _ soundFontId: SoundFont.ID) throws -> TaggedSoundFont {
    @Dependency(\.defaultDatabase) var database
    return try database.write { try TaggedSoundFont(soundFontId: soundFontId, tagId: tagId).insertAndFetch($0) }
  }
  
  public func untagSoundFont(_ tagId: Tag.ID, soundFontId: SoundFont.ID) throws {
    if tagId.isUbiquitous { throw ModelError.untaggingUbiquitous }
    @Dependency(\.defaultDatabase) var database
    let result = try database.write {
      try TaggedSoundFont.deleteOne($0, key: ["soundFontId": soundFontId, "tagId": tagId])
    }
    if !result {
      throw ModelError.notTagged
    }
  }
}
