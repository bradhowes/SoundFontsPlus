// Copyright © 2025 Brad Howes. All rights reserved.

import Dependencies
import Engine
import Foundation
import OSLog
import SharingGRDB

private let log = Logger(category: "Database")

// swiftlint:disable:next function_body_length
public func appDatabase() throws -> any DatabaseWriter {
  @Dependency(\.context) var context

  let database: any DatabaseWriter
  var configuration = Configuration()

  configuration.foreignKeysEnabled = true
  configuration.prepareDatabase { db in

#if DEBUG
    db.trace(options: .profile) {
      if context == .live {
        log.debug("\($0.expandedDescription)")
      } else {
        print("\($0.expandedDescription)")
      }
    }
#endif
  }

  if context == .live {
    let path = URL.documentsDirectory.appending(component: "db.sqlite").path()
    log.info("open \(path)")
    database = try DatabasePool(path: path, configuration: configuration)
  } else {
    database = try DatabaseQueue(configuration: configuration)
  }

  var migrator = DatabaseMigrator()
#if DEBUG
  migrator.eraseDatabaseOnSchemaChange = true
#endif

  SoundFont.migrate(&migrator)
  Preset.migrate(&migrator)
  AudioConfig.migrate(&migrator)
  DelayConfig.migrate(&migrator)
  ReverbConfig.migrate(&migrator)
  FontTag.migrate(&migrator)
  TaggedSoundFont.migrate(&migrator)

  migrator.registerMigration("Add ubiquitous tags") { db in
    let drafts: [FontTag.Draft] = FontTag.Ubiquitous.allCases.enumerated().map {
      .init(displayName: $0.1.displayName, ordering: $0.0)
    }
    try FontTag.insert {
      drafts
    }.execute(db)
  }

  migrator.registerMigration("Add builtin fonts") { db in
    for sf2 in SF2ResourceFileTag.allCases {
      SoundFont.insert(db, sf2: sf2)
    }
  }

  migrator.registerMigration("Add global audio configs") { db in
    try AudioConfig.insert {
      AudioConfig.Draft(AudioConfig(id: AudioConfig.global))
    }.execute(db)
    try DelayConfig.insert {
      DelayConfig.Draft(DelayConfig(id: DelayConfig.global))
    }.execute(db)
    try ReverbConfig.insert {
      ReverbConfig.Draft(ReverbConfig(id: ReverbConfig.global))
    }.execute(db)
  }

#if DEBUG && targetEnvironment(simulator)
  if context != .test {
    migrator.registerMigration("Seed sample data") { db in
      try db.seedSampleData()
    }
  }
#endif

  try migrator.migrate(database)

  return database
}

#if DEBUG
extension Database {
  func seedSampleData() throws {
  }
}
#endif
