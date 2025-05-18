import AVFoundation
import SharingGRDB
import Tagged

@Table
public struct AudioConfig: Hashable, Identifiable {
  public typealias ID = Tagged<Self, Int64>

  public let id: ID
  public var gain: AUValue
  public var pan: AUValue
  public var keyboardLowestNoteEnabled: Bool
  public var keyboardLowestNote: Int?
  public var pitchBendRange: Int?
  public var presetTuning: AUValue?
  public var presetTranspose: Int?
  public let favoriteId: Favorite.ID?
  public let presetId: Preset.ID?
}

extension AudioConfig {

  static func migrate(_ migrator: inout DatabaseMigrator) {
    migrator.registerMigration(Self.tableName) { db in
      try #sql(
      """
      CREATE TABLE "\(raw: Self.tableName)" (
        "id" INTEGER PRIMARY KEY AUTOINCREMENT,
        "gain" REAL NOT NULL,
        "pan" REAL NOT NULL,
        "keyboardLowestNoteEnabled" INTEGER NOT NULL CHECK ("keyboardLowestNoteEnabled" in (0, 1)),
        "keyboardLowestNote" INTEGER NOT NULL,
        "pitchBendRange" INTEGER NOT NULL,
        "presetTuning" REAL NOT NULL,
        "presetTranspose" INTEGER NOT NULL,
        "favoriteId" INTEGER,
        "presetId" INTEGER,
      
        FOREIGN KEY("favoriteId") REFERENCES "favorites"("id") ON DELETE CASCADE,
        FOREIGN KEY("presetId") REFERENCES "presets"("id") ON DELETE CASCADE
      ) STRICT
      """
      )
      .execute(db)
    }
  }
}
