// Copyright © 2025 Brad Howes. All rights reserved.

import SwiftUI

public struct CheckToggleStyle: ToggleStyle {

  public init() {}

  public func makeBody(configuration: Configuration) -> some View {
    Button {
      configuration.isOn.toggle()
    } label: {
      Label {
        configuration.label
      } icon: {
        Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "circle")
          .foregroundStyle(configuration.isOn ? Color.accentColor : .secondary)
          .accessibility(label: Text(configuration.isOn ? "Checked" : "Unchecked"))
          .imageScale(.large)
      }
    }
    .buttonStyle(.plain)
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
        Text("Hello")
          .foregroundStyle(helloIsOn ? .primary : .secondary)
        Spacer()
        Toggle(isOn: $helloIsOn) {}
          .checkedStyle()
      }
      HStack {
        Text("World")
          .foregroundStyle(worldIsOn ? .primary : .secondary)
        Spacer()
        Toggle(isOn: $worldIsOn) {}
          .checkedStyle()
      }
    }
    .navigationTitle("Toggle Buttons")
  }

}
