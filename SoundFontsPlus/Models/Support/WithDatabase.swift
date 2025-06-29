import Dependencies
import SharingGRDB

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

extension StructuredQueriesCore.Statement {

  @inlinable
  public func fetchOneForced(_ db: Database) throws -> QueryValue.QueryOutput where QueryValue: QueryRepresentable {
    guard let found = try fetchCursor(db).next() else {
      throw DatabaseError(resultCode: .SQLITE_ERROR, message: "unexpectedly failed fetchOne")
    }
    return found
  }
}
