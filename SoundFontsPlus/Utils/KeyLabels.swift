import Foundation

public enum KeyLabels: String, CaseIterable, Identifiable, Sendable {
  case none = "Off"
  case cOnly = "C"
  case all = "All"

  public var id: Self { self }
  public var cOnly: Bool { self == .cOnly }
  public var all: Bool { self == .all }
}
