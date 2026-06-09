// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation

@frozen
public enum KeyLabels: String, CaseIterable, Identifiable {
  case none = "None"
  case cOnly = "Only C"
  case all = "All"

  public var id: Self { self }
  public var cOnly: Bool { self == .cOnly }
  public var all: Bool { self == .all }
}
