// Copyright © 2025 Brad Howes. All rights reserved.

import Dependencies
import SQLiteData

public func withDatabaseWriter(_ closure: (Database) throws -> Void) {
  @Dependency(\.defaultDatabase) var database
  withErrorReporting {
    try database.write { db in
      try closure(db)
    }
  }
}

public func withDatabaseWriter<T>(_ closure: (Database) throws -> T) -> T? {
  @Dependency(\.defaultDatabase) var database
  return withErrorReporting {
    try database.write { db in
      try closure(db)
    }
  }
}

public func withDatabaseReader<T>(_ closure: (Database) throws -> T) -> T? {
  @Dependency(\.defaultDatabase) var database
  return withErrorReporting {
    try database.read { db in
      try closure(db)
    }
  }
}
