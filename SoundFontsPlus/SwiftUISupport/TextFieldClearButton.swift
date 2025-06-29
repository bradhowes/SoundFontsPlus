// Copyright © 2025 Brad Howes. All rights reserved.

import SwiftUI

/**
 View modifier that adds a 'clear' button that removes all text from a text field and also gives it focus.
 */
struct ClearButton: ViewModifier {
  @Binding var text: String

  func body(content: Content) -> some View {
    ZStack(alignment: .trailing) {
      content

      if !text.isEmpty {
        Button {
          text = ""
        } label: {
          Image(systemName: "multiply.circle.fill")
            .foregroundStyle(.gray)
        }
        .padding(.trailing, 8)
      }
    }
  }
}

extension View {
  func clearButton(text: Binding<String>) -> some View {
    modifier(ClearButton(text: text))
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
        .clearButton(text: $text)
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
