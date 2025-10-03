// Copyright © 2025 Brad Howes. All rights reserved.

import SwiftUI

/**
 View modifier that adds a 'clear' button that removes all text from a text field and also gives it focus.
 */
public struct ClearButton: ViewModifier {
  private let action: () -> Void

  public init(action: @escaping () -> Void) {
    self.action = action
  }

  public func body(content: Content) -> some View {
    ZStack(alignment: .trailing) {
      content
      Button {
        action()
      } label: {
        Image(systemName: "multiply.circle.fill")
          .foregroundStyle(.gray)
          .frame(width: 32, height: 32)
          .contentShape(Rectangle())
      }
      .padding(.trailing, 8)
    }
  }
}

extension View {
  public func clearButton(action: @escaping () -> Void) -> some View {
    modifier(ClearButton(action: action))
  }
}

private struct Demo: View {
  @State var text: String
  @FocusState var displayNameFieldIsFocused: Bool

  init(text: String, displayNameFieldIsFocused: Bool) {
    self.text = text
    self.displayNameFieldIsFocused = displayNameFieldIsFocused
  }

  var body: some View {
    Section(header: Text("Name")) {
      TextField("Display Name", text: $text)
        .clearButton { text = "" }
        .textInputAutocapitalization(.never)
        .textFieldStyle(.roundedBorder)
        .focused($displayNameFieldIsFocused)
        .disableAutocorrection(true)
    }
  }
}

struct TextFieldClearButton_Previews: PreviewProvider {
  static var previews: some View {
    Form {
      Demo(text: "Testing", displayNameFieldIsFocused: true)
      Demo(text: "Another", displayNameFieldIsFocused: false)
    }
  }
}
