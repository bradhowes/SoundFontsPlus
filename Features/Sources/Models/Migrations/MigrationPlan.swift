import Dependencies
import Foundation
import SwiftData

enum MigrationPlan: SchemaMigrationPlan {

  static var schemas: [any VersionedSchema.Type] {
    [
      SchemaV1.self,
    ]
  }

  static var stages: [MigrationStage] {
    [
      // .lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self),
    ]
  }
}
