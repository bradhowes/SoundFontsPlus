import SwiftUI

public enum KeyboardKeyLabel {
  case none
  case cOnly
  case all
}

extension EnvironmentValues {
  @Entry public var appPanelBackground: Color = .init(red: 0.08, green: 0.08, blue: 0.08)
  @Entry public var keyboardKeyHeight: Double = 220
  @Entry public var keyboardKeyWidth: Double = 64
  @Entry public var keyboardKeyLabel: KeyboardKeyLabel = .cOnly
  @Entry public var keyboardFixed: Bool = false
}

extension View {
  public func appPanelBackground(_ value: Color) -> some View {
    environment(\.appPanelBackground, value)
  }

  public func keyboardKeyHeight(_ value: Double) -> some View {
    environment(\.keyboardKeyHeight, value)
  }

  public func keyboardKeyWidth(_ value: Double) -> some View {
    environment(\.keyboardKeyWidth, value)
  }

  public func keyboardKeyLabel(_ value: KeyboardKeyLabel) -> some View {
    environment(\.keyboardKeyLabel, value)
  }

  public func keyboardFixed(_ value: Bool) -> some View {
    environment(\.keyboardFixed, value)
  }
}
