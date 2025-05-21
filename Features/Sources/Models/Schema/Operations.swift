import Dependencies
import SharingGRDB

public enum Operations {

  public static var presetSource: SoundFont.ID? {
    @Shared(.activeState) var activeState
    return activeState.selectedSoundFontId ?? activeState.activeSoundFontId
  }

  public static var activePresetName: String {
    @Shared(.activeState) var activeState
    guard let presetId = activeState.activePresetId else { return "-" }
    let query = Preset.select{ $0.displayName }.where { $0.id == presetId }
    @Dependency(\.defaultDatabase) var database
    return (try? database.read { try query.fetchOne($0) }) ?? "-"
  }

  public static func preset(_ presetId: Preset.ID) -> Preset? {
    let query = Preset.all.where { $0.id == presetId }
    @Dependency(\.defaultDatabase) var database
    return try? database.read { try query.fetchOne($0) }
  }

  public static var presets: [Preset] {
    guard let soundFontId = presetSource else { return [] }
    let query = Preset.all.where { $0.soundFontId == soundFontId && $0.visible }.order(by: \.index)
    @Dependency(\.defaultDatabase) var database
    return (try? database.read { try query.fetchAll($0) }) ?? []
  }

  public static var allPresets: [Preset] {
    guard let soundFontId = presetSource else { return [] }
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
  
  public static func tagSoundFont(_ tagId: Tag.ID, soundFontId: SoundFont.ID) -> Bool {
    if tagId.isUbiquitous { return false }
    let query = TaggedSoundFont.insert(.init(soundFontId: soundFontId, tagId: tagId))
    @Dependency(\.defaultDatabase) var database
    return (try? database.write { try query.execute($0); return true }) ?? false
  }
  
  public static func untagSoundFont(_ tagId: Tag.ID, soundFontId: SoundFont.ID) -> Bool {
    if tagId.isUbiquitous { return false }
    let query = TaggedSoundFont.all.delete().where { $0.soundFontId.eq(soundFontId) && $0.tagId.eq(tagId) }
    @Dependency(\.defaultDatabase) var database
    return (try? database.write { try query.execute($0); return true }) ?? false
  }

  public static func deleteTag(_ tagId: Tag.ID) -> Bool {
    if tagId.isUbiquitous { return false }
    let query = Tag.all.delete().where { $0.id.eq(tagId) }
    @Dependency(\.defaultDatabase) var database
    return (try? database.write { try query.execute($0); return true }) ?? false
  }

  public static func updateTags(_ tagsInfo: [(Tag.ID, String)]) -> Bool {
    @Dependency(\.defaultDatabase) var database
    for tagInfo in tagsInfo.enumerated() {
      let newName = tagInfo.1.1.trimmingCharacters(in: .whitespaces)
      let query = Tag.update {
        if !newName.isEmpty {
          $0.displayName = newName
        }
        $0.ordering = tagInfo.0
      }.where {
        $0.id.eq(tagInfo.1.0)
      }
      if (try? database.write { try query.execute($0) }) == nil {
        return false
      }
    }

    return true
  }
}
