import Dependencies
import Engine
import Foundation
import GRDB
import SF2ResourceFiles

public extension DatabaseWriter where Self == DatabaseQueue {

  static func appDatabase(
    path: URL? = nil,
    configuration: Configuration? = nil,
    addTags: Bool = true,
    addBuiltIns: Bool = true
  ) throws -> Self {
    var config = configuration ?? Configuration()
    #if DEBUG
        config.publicStatementArguments = true
    config.prepareDatabase {
      db in db.trace {
        print($0)
      }
    }
    #endif

    let databaseQueue: DatabaseQueue

    @Dependency(\.context) var context

    if context == .live {
      let dbPath = (path ?? URL.documentsDirectory.appending(component: "db.sqlite")).path()
      databaseQueue = try DatabaseQueue(path: dbPath, configuration: config)
    } else {
      databaseQueue = try DatabaseQueue(configuration: config)
    }

    var migrator = DatabaseMigrator()
#if DEBUG
    migrator.eraseDatabaseOnSchemaChange = true
#endif

    V1.migrate(into: &migrator)

#if DEBUG && targetEnvironment(simulator)
    if context != .test {
      migrator.registerMigration("Seed sample data") { db in
        try db.seedSampleData()
      }
    }
#endif

    if addTags || addBuiltIns {
      try databaseQueue.write { db in
        if try Tag.fetchCount(db) == 0 {

          // Install predefined tags
          for tag in Tag.Ubiquitous.allCases.enumerated() {
            _ = try Tag.make(db, name: tag.1.name)
          }
        }

        if try addBuiltIns && SoundFont.fetchCount(db) == 0 {
          // Install predefined SF2
          for sf2 in SF2ResourceFileTag.allCases {
            _ = try SoundFont.make(db, builtin: sf2)
          }
        }
      }
    }

    return databaseQueue
  }
}

#if DEBUG
extension Database {
  func seedSampleData() throws {
  }
}
#endif
