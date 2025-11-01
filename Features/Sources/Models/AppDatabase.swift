// Copyright © 2025 Brad Howes. All rights reserved.

import BaseSupport
import Dependencies
import Foundation
import OSLog
import SF2Resources
import SQLiteData

private let log = Logger(category: "appDatabase")

// swiftlint:disable:next function_body_length
public func appDatabase(
  fonts: [SF2ResourceTag] = SF2ResourceTag.allCases,
  loadAllPresets: Bool = true,
  seeder: ((Database) throws -> Void)? = nil
) throws -> any DatabaseWriter {
  @Dependency(\.context) var context
  let database: any DatabaseWriter
  var configuration = GRDB.Configuration()

  log.info("appDatabase BEGIN - fonts: \(fonts) loadAllPresets: \(loadAllPresets)")

  configuration.foreignKeysEnabled = true

#if DEBUG

  if !ProcessInfo.processInfo.isOnGithub {
    print("isOnGithub is false")
    configuration.prepareDatabase { db in
      db.trace(options: .profile) {
        if context == .live {
          log.debug("\($0.expandedDescription)")
        } else {
          print("\($0.expandedDescription)")
        }
      }
    }
  }

#endif // DEBUG

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
#endif // DEBUG

  SoundFont.migrate(&migrator)
  Preset.migrate(&migrator)
  AudioConfig.migrate(&migrator)
  DelayConfig.migrate(&migrator)
  ReverbConfig.migrate(&migrator)
  FontTag.migrate(&migrator)
  TaggedSoundFont.migrate(&migrator)
  MIDIConfig.migrate(&migrator)

  migrator.registerMigration("Add ubiquitous tags") { db in
    let drafts: [FontTag.Draft] = FontTag.Ubiquitous.allCases.enumerated().map {
      .init(displayName: $0.1.displayName, ordering: $0.0)
    }
    try FontTag.insert {
      drafts
    }.execute(db)
  }

  migrator.registerMigration("Add builtin fonts") { db in
    for sf2 in fonts {
      log.info("add \(sf2)")
      let limitedLoading: Bool = context == .test && loadAllPresets == false
      try SoundFont.addBuiltIn(db, sf2: sf2, limitedLoading: limitedLoading)
    }
  }

  try migrator.migrate(database)

  if !fonts.isEmpty {
    // Update locations of builtin SF2 files everytime we startup since app container location could change.
    try database.write { db in
      for sf2 in SF2ResourceTag.allCases {
        withErrorReporting {
          let soundFontKind: SoundFontKind = .builtin(resource: sf2.url)
          let (kind, location) = try soundFontKind.data()
          try SoundFont
            .where { $0.id.eq(sf2.id) }
            .update {
              $0.kind = kind
              $0.location = location
            }.execute(db)
        }
      }
    }
  }

  if let seeder {
    try database.write { db in
      try seeder(db)
    }
  }

  return database
}

public func previewDatabase(
  fonts: [SF2ResourceTag] = [.fluidFont, .rolandNicePiano],
  loadAllPresets: Bool = false,
  seeder: ((Database) throws -> Void)? = nil
) -> any DatabaseWriter {
  try! appDatabase(fonts: fonts, loadAllPresets: loadAllPresets, seeder: seeder)
}

