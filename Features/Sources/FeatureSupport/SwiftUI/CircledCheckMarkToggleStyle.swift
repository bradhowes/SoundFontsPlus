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
        configuration.label
          .foregroundStyle(configuration.isOn ? .primary : .secondary)
          .animation(.smooth, value: configuration.isOn)
        Spacer()
        buttonView(configuration: configuration)
      }
    }
  }

  private func buttonView(configuration: Configuration) -> some View {
    Button {
      configuration.isOn.toggle()
    } label: {
      Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "circle")
        .foregroundStyle(configuration.isOn ? Color.accentColor : .secondary)
        .accessibility(label: Text(configuration.isOn ? "Checked" : "Unchecked"))
        .imageScale(.large)
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

#Preview {
  @Previewable @State var helloIsOn = true
  @Previewable @State var worldIsOn = false

  NavigationStack {
    List {
      HStack {
        Toggle(isOn: $helloIsOn) {
          Text("Hello")
            .foregroundStyle(helloIsOn ? .primary : .secondary)
        }
        .circledCheckMarkToggleStyle()
      }
      HStack {
        Toggle(isOn: $worldIsOn) {
          Text("World")
            .foregroundStyle(worldIsOn ? .primary : .secondary)
        }
        .circledCheckMarkToggleStyle()
      }
    }
    .navigationTitle("Toggle Buttons")
  }

}
