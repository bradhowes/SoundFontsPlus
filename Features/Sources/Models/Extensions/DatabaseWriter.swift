// Copyright © 2025 Brad Howes. All rights reserved.

import Dependencies
import SQLiteData

extension DatabaseWriter {

  public func withWriter(_ closure: (Database) throws -> Void) {
    withErrorReporting {
      try self.write { db in
        try closure(db)
      }
    }
  }

  public func withWriter<T>(_ closure: (Database) throws -> T) -> T? {
    return withErrorReporting {
      try self.write { db in
        try closure(db)
      }
    }
  }

  public func withReader<T>(_ closure: (Database) throws -> T) -> T? {
    return withErrorReporting {
      try self.read { db in
        try closure(db)
      }
    }
  }

}

public func witDatabaseWriter(_ closure: (Database) throws -> Void) {
  @Dependency(\.defaultDatabase) var database
  database.withWriter(closure)
}

public func withDatabaseWriter<T>(_ closure: (Database) throws -> T) -> T? {
  @Dependency(\.defaultDatabase) var database
  return database.withWriter(closure)
}

public func withDatabaseReader<T>(_ closure: (Database) throws -> T) -> T? {
  @Dependency(\.defaultDatabase) var database
  return database.withReader(closure)
}
