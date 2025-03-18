// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation
import Dependencies
import GRDB
import Tagged

public struct TaggedSoundFont: Codable, FetchableRecord, MutablePersistableRecord, TableCreator {
  public let soundFontId: SoundFont.ID
  public let tagId: Tag.ID

  enum Columns {
    static let soundFontId = Column(CodingKeys.soundFontId)
    static let tagId = Column(CodingKeys.tagId)
  }

  static func createTable(in db: Database) throws {
    try db.create(table: databaseTableName) { table in
      table.primaryKey {
        table.belongsTo(SoundFont.databaseTableName, onDelete: .cascade).notNull()
        table.belongsTo(Tag.databaseTableName, onDelete: .cascade).notNull()
      }
    }
  }
}

// MARK: SoundFont and Tag associations
extension TaggedSoundFont {
  static let soundFont = belongsTo(SoundFont.self)
  static let tag = belongsTo(Tag.self)
}
