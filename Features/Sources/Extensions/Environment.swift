import SwiftUI

extension EnvironmentValues {
  @Entry public var appPanelBackground: Color = .init(red: 0.08, green: 0.08, blue: 0.08)
}

extension View {
  public func appPanelBackground(_ value: Color) -> some View {
    environment(\.appPanelBackground, value)
  }
}
