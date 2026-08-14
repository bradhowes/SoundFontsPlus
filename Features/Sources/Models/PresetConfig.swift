// Copyright © 2025 Brad Howes. All rights reserved.

public import SQLiteData
public import Tagged

@Table
nonisolated public struct PresetConfig {

  @Selection
  public struct ID {
    public var presetId: Preset.ID
    public var generatorId: Int
  }

  public let id: ID
  /// The custom value to use for the generator
  public var value: Double
}

extension PresetConfig {

  static func migrate(_ migrator: inout DatabaseMigrator) {
    migrator.registerMigration(Self.tableName) { db in
      try #sql(
      """
      CREATE TABLE "\(raw: Self.tableName)" (
        "presetId" INTEGER NOT NULL,
        "generatorId" INTEGER NOT NULL,
        "value" REAL NOT NULL,
        PRIMARY KEY ("presetId", "generatorId"),
        FOREIGN KEY("presetId") REFERENCES "\(raw: Preset.tableName)"("id") ON DELETE CASCADE
      ) STRICT, WITHOUT ROWID
      """
      )
      .execute(db)
    }
  }
}

extension PresetConfig {

  /**
   Fetch the row for a given ID.

   - parameter presetId: the preset ID to look for
   - returns: the value found or `nil`.
   */
  public static func with(presetId: Preset.ID?) -> [PresetConfig] {
    guard let presetId else { return [] }
    return withDatabaseReader { db in
      try Self.all
        .where {
          $0.id.presetId.eq(presetId)
        }.fetchAll(db)
    } ?? []
  }

  /**
   Save the given config.

   - parameter config: the draft to apply
   - returns: the AudioConfig from the database
   */
  @discardableResult
  public static func save(config: Draft) -> Self? {
    withDatabaseWriter { db in
      try Self.upsert {
        config
      }
      .returning(\.self)
      .fetchOne(db)
    } ?? nil
  }

  /**
   Create a duplicate of the PresetConfig instance.

   - parameter presetId: the Preset.ID to associate with
   - returns: cloned instance
   */
  @discardableResult
  public func clone(presetId: Preset.ID) -> Self? {
    withDatabaseWriter { db in
      try Self.insert {
        Draft(
          id: PresetConfig.ID(presetId: presetId, generatorId: self.id.generatorId),
          value: self.value
        )
      }
      .returning(\.self)
      .fetchOne(db)
    } ?? nil
  }
}

extension PresetConfig.ID: Hashable, Sendable {}
extension PresetConfig: Hashable, Sendable {}

extension PresetConfig.Draft: Equatable, Sendable {

  public init(
    presetId: Preset.ID,
    generatorId: Int,
    value: Double
  ) {
    self.id = PresetConfig.ID(presetId: presetId, generatorId: generatorId)
    self.value = value
  }
}
