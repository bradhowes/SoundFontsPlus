import Foundation
import Dependencies
import GRDB
import IdentifiedCollections
import Tagged
import Sharing

public struct TagInfo: FetchableRecord, Decodable, Equatable, Identifiable {
  public var id: Tag.ID
  public var name: String
  public var taggedSoundFontCount: Int

  public static func from(_ tag: Tag) -> Self {
    .init(id: tag.id, name: tag.name, taggedSoundFontCount: 0)
  }

  public static func all() -> [TagInfo] {
    @Dependency(\.defaultDatabase) var database
    let request = Tag
      .select(Tag.Columns.id, Tag.Columns.name)
      .annotated(with: Tag.taggedSoundFonts.count)
      .asRequest(of: TagInfo.self)
    return (try? database.read { try request.fetchAll($0) }) ?? []
  }
}
