import ComposableArchitecture
import Models
import SwiftUI

public enum Support {

  static func generateTagsList(from soundFont: SoundFontModel) -> String {
    soundFont.tags.map(\.name).sorted().joined(separator: ", ")
  }
}
