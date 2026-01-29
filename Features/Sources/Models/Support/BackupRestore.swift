// Copyright © 2025 Brad Howes. All rights reserved.

import BaseSupport
import Dependencies
import Foundation
import GRDB

// Based off of code in https://github.com/groue/GRDB.swift/discussions/1798#discussioncomment-13926896
public enum BackupManager {

  // swiftlint:disable:next function_body_length
  public static func backup() throws(BackupError) -> URL {
    @Dependency(\.defaultDatabase) var database
    @Dependency(\.fileManager) var fileManager
    @Dependency(\.date.now) var now
    @Dependency(\.uuid) var uuid

    guard let cloudDocuments = fileManager.cloudDocumentsDirectory() else {
      log.info("no cloud documents directory available")
      throw BackupError.noCloudDirectory
    }

    let backupName = "Backup - " + now.ISO8601Format(.init().timeSeparator(.omitted))
    let tmpDirectory = URL.temporaryDirectory.appending(component: uuid().uuidString, directoryHint: .isDirectory)
    let backupDirectory = tmpDirectory.appending(component: backupName, directoryHint: .isDirectory)

    defer {
      try? fileManager.removeItem(backupDirectory)
    }

    do {
      try fileManager.createDirectory(backupDirectory)
    } catch {
      throw BackupError.backupCreationFailed(error)
    }

    let version: String = Bundle.main.releaseVersionNumber
    let backupFile: URL = backupDirectory.appending(path: "backup.sqlite-\(version)", directoryHint: .notDirectory)

    do {
      let backupDatabase: DatabaseQueue = try DatabaseQueue(path: backupFile.path)
      try database.backup(to: backupDatabase)

      try backupDatabase.writeWithoutTransaction { db in
        _ = try db.execute(sql: "PRAGMA journal_mode=DELETE")
        _ = try db.execute(sql: "PRAGMA wal_checkpoint(TRUNCATE)")
        let integrityResult = try String.fetchOne(db, sql: "PRAGMA integrity_check")
        guard integrityResult == "ok" else {
          throw BackupError.databaseIntegrityCheckFailed
        }

        let check = try Row.fetchAll(db, sql: "PRAGMA foreign_key_check")
        guard check.isEmpty else {
          throw BackupError.databaseForeignKeyCheckFailed
        }
      }

      try backupDatabase.vacuum()
      try backupDatabase.close()

    } catch let error as BackupError {
      throw error
    } catch {
      throw BackupError.backupCreationFailed(error)
    }

    // Now move the temporary directory into the app iCloud documents directory.
    let finalDestination = cloudDocuments.appending(component: backupName, directoryHint: .isDirectory)

    do {
      try fileManager.moveItem(backupDirectory, finalDestination)
    } catch {
      throw BackupError.moveItemFailed(error)
    }

    // Copy the SF2 files to the iCloud directory.
    do {
      try fileManager.copyItem(
        fileManager.fontFilesDirectory(),
        finalDestination.appending(component: FileManager.fontFilesDirectoryName, directoryHint: .isDirectory)
      )
    } catch {
      throw BackupError.fontFilesCopyFailed(error)
    }

    return finalDestination
  }

  public static func restore(url: URL) throws {
    @Dependency(\.defaultDatabase) var database
    @Dependency(\.fileManager) var fileManager
  }
}

public enum BackupError: Error {
  case noCloudDirectory
  case backupCreationFailed(Error)
  case databaseBackupFailed(Error)
  case databaseIntegrityCheckFailed
  case databaseForeignKeyCheckFailed
  case fontFilesCopyFailed(Error)
  case moveItemFailed(Error)

  public var description: String {
    switch self {

    case .noCloudDirectory:
      return "There is no iCloud directory available to use."
    case .backupCreationFailed(let error):
      return "Failed to create a backup directory - \(error.localizedDescription)"
    case .databaseBackupFailed(let error):
      return "Failed database backup - \(error.localizedDescription)"
    case .databaseIntegrityCheckFailed:
      return "Verification of database backup integrity failed."
    case .databaseForeignKeyCheckFailed:
      return "Verificaion of database foreign keys failed."
    case .fontFilesCopyFailed(let error):
      return "Failed to copy contents of the installed sound font files - \(error.localizedDescription)"
    case .moveItemFailed(let error):
      return "Failed to move backup folder to cloud documents directory - \(error.localizedDescription)"
    }
  }
}

public enum RestoreError: Error {
  case noCloudDirectory
  case backupCreationFailed(Error)
  case databaseBackupFailed(Error)
  case databaseIntegrityCheckFailed
  case databaseForeignKeyCheckFailed
  case fontFilesCopyFailed(Error)
  case moveItemFailed(Error)

  public var description: String {
    switch self {

    case .noCloudDirectory:
      return "There is no iCloud directory available to use."
    case .backupCreationFailed(let error):
      return "Failed to create a backup directory - \(error.localizedDescription)"
    case .databaseBackupFailed(let error):
      return "Failed database backup - \(error.localizedDescription)"
    case .databaseIntegrityCheckFailed:
      return "Verification of database backup integrity failed."
    case .databaseForeignKeyCheckFailed:
      return "Verificaion of database foreign keys failed."
    case .fontFilesCopyFailed(let error):
      return "Failed to copy contents of the installed sound font files - \(error.localizedDescription)"
    case .moveItemFailed(let error):
      return "Failed to move backup folder to cloud documents directory - \(error.localizedDescription)"
    }
  }
}

private let log = Logger(category: "BackupManager")
