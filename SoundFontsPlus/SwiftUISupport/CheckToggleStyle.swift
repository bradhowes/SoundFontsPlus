// Copyright © 2025 Brad Howes. All rights reserved.

import SwiftUI

public struct CheckToggleStyle: ToggleStyle {

  public init() {}

  public func makeBody(configuration: Configuration) -> some View {
    HStack {
      configuration.label
        .foregroundStyle(configuration.isOn ? .primary : .secondary)
        .animation(.smooth, value: configuration.isOn)
      Spacer()
      Button {
        configuration.isOn.toggle()
      } label: {
        Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "circle")
          .foregroundStyle(configuration.isOn ? Color.accentColor : .secondary)
          .accessibility(label: Text(configuration.isOn ? "Checked" : "Unchecked"))
          .imageScale(.large)
          .animation(.smooth, value: configuration.isOn)
      }
      .buttonStyle(.plain)
      .animation(.smooth, value: configuration.isOn)
    }
  }
}

extension View {
  public func checkedStyle() -> some View {
    toggleStyle(CheckToggleStyle())
  }
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
        .checkedStyle()
      }
      HStack {
        Toggle(isOn: $worldIsOn) {
          Text("World")
            .foregroundStyle(worldIsOn ? .primary : .secondary)
        }
        .checkedStyle()
      }
    }
    .navigationTitle("Toggle Buttons")
  }

}
