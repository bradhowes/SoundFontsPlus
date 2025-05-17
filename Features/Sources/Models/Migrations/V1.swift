import Dependencies
import Foundation
import GRDB

enum V1 {

  static func migrate(into migrator: inout DatabaseMigrator) {
    migrator.registerMigration("SchemaV1") { db in

//      // NOTE: order is important for GRDB - tables that are pointed to in `belongsTo` (eg. SoundFont) need to appear
//      // before the table(s) that contain(s) `belongsTo` statements (eg. Preset).
//      let tables: [any TableCreator.Type] = [
//        SoundFont.self,
//        Preset.self,
//        Favorite.self,
//        AudioConfig.self,
//        DelayConfig.self,
//        ReverbConfig.self,
//        Tag.self,
//        TaggedSoundFont.self
//      ]
//
//      for each in tables {
//        try each.createTable(in: db)
//      }
    }
  }
}
