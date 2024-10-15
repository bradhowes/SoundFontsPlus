import Foundation
import Tagged

public struct TagInfo: Equatable, Identifiable {
  let key: TagModel.Key
  let ordering: Int
  let editable: Bool
  var name: String

  public init(
    key: TagModel.Key,
    ordering: Int,
    editable: Bool,
    name: String
  ) {
    self.id = .init(uuid)
    self.uuid = uuid
    self.ordering = ordering
    self.editable = editable
    self.name = name
  }
}
