import GRDB
import Tagged

protocol TableCreator: TableRecord {
  static func createTable(in db: Database) throws
  static func deleteAll(_ db: Database) throws -> Int
}

extension TableDefinition {

  @discardableResult
  func autoIncrementedPrimaryKey(_ column: Column) -> ColumnDefinition {
    autoIncrementedPrimaryKey(column.name)
  }

  @discardableResult
  func column(_ name: Column, _ kind: Database.ColumnType?) -> ColumnDefinition {
    column(name.name, kind)
  }
}

extension Tagged: @retroactive SQLExpressible
where RawValue: SQLExpressible {}

extension Tagged: @retroactive StatementBinding
where RawValue: StatementBinding {}

extension Tagged: @retroactive StatementColumnConvertible
where RawValue: StatementColumnConvertible {}

extension Tagged: @retroactive DatabaseValueConvertible
where RawValue: DatabaseValueConvertible {}
