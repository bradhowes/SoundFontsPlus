import SwiftUI

public enum KeyboardKeyLabel: String, CaseIterable, Identifiable {
  case none = "None"
  case cOnly = "C Only"
  case all = "All"

  public var id: Self { self }
}

extension EnvironmentValues {
  @Entry public var keyboardKeyHeight: Double = 220
  @Entry public var keyboardKeyWidth: Double = 64
  @Entry public var keyboardKeyLabel: KeyboardKeyLabel = .cOnly
  @Entry public var keyboardFixed: Bool = false
}

extension View {

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
