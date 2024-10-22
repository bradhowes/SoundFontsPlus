import ComposableArchitecture
import Models
import SwiftUI

public enum Support {

  static func generateTagsList(from tags: [TagModel]) -> String {
    tags.map(\.name).sorted().joined(separator: ", ")
  }
}
