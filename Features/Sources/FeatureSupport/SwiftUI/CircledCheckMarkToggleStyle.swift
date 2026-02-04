// Copyright © 2025 Brad Howes. All rights reserved.

import SwiftUI

public struct CircledCheckMarkToggleStyle: ToggleStyle {
  let hideLabel: Bool

  public init(hideLabel: Bool = false) {
    self.hideLabel = hideLabel
  }

  public func makeBody(configuration: Configuration) -> some View {
    if hideLabel {
      buttonView(configuration: configuration)
    } else {
      HStack {
        CustomLabel(configuration: configuration)
        Spacer()
        buttonView(configuration: configuration)
      }
    }
  }

  private struct CustomLabel: View {
    let configuration: ToggleStyle.Configuration
    @Environment(\.isEnabled) var isEnabled
    var body: some View {
      configuration.label
      // .fontWeight(isEnabled ? (configuration.isOn ? .regular : .thin) : .ultraLight)
        .foregroundStyle(isEnabled ? (configuration.isOn ? .primary : .secondary) : .tertiary)
        .animation(.smooth, value: configuration.isOn)
        .animation(.smooth, value: isEnabled)
    }
  }

  private func buttonView(configuration: Configuration) -> some View {
    Button {
      configuration.isOn.toggle()
    } label: {
      Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "circle")
        .accessibility(label: Text(configuration.isOn ? "Checked" : "Unchecked"))
        .imageScale(.large)
        .foregroundStyle(Color.mainAccentColor)
        .animation(.smooth, value: configuration.isOn)
    }
    .animation(.smooth, value: configuration.isOn)
  }
}

extension ToggleStyle where Self == ButtonToggleStyle {

  public static var circledCheckMark: CircledCheckMarkToggleStyle { .init() }

  public static var circledCheckMarkNoLabel: CircledCheckMarkToggleStyle { .init(hideLabel: true) }
}

extension View {

  public func circledCheckMarkToggleStyle() -> some View { toggleStyle(.circledCheckMark) }
}

#if DEBUG

#Preview {
  @Previewable @State var helloIsOn = true
  @Previewable @State var disabled = false

  NavigationStack {
    List {
      HStack {
        Toggle(isOn: $helloIsOn) {
          Text("Hello")
        }
        .circledCheckMarkToggleStyle()
        .disabled(disabled)
      }
      HStack {
        Toggle(isOn: $helloIsOn) {
          Text("Hello")
        }
        .disabled(disabled)
      }
      HStack {
        Toggle(isOn: $disabled) {
          Text("Disabled")
        }
      }
    }
    .navigationTitle("Toggle Buttons")
  }

}

#endif // DEBUG
