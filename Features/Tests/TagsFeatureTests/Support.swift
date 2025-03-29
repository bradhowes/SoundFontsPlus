import ComposableArchitecture
import Foundation
import GRDB
import SF2ResourceFiles
import Models
import Testing

enum TestSupport {

  @MainActor
  static func initialize(_ body: (Array<Models.Tag>) async throws -> Void) async throws {
    try await withDependencies {
      $0.defaultDatabase = try DatabaseQueue.appDatabase()
    } operation: {
      @Dependency(\.defaultDatabase) var database
      let tags = try await database.read { try Tag.order(Column("id")).fetchAll($0) }
      try await body(tags)
    }
  }
}
