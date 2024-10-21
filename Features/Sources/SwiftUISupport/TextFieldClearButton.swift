//
//  SwiftUIView.swift
//
//
//  Created by Brad Howes on 18/05/2024.
//

import SwiftUI

/**
 View modifier that adds a 'clear' button that removes all text from a text field and also gives it focus.
 */
struct TextFieldClearButton: ViewModifier {
  @Binding var fieldText: String
  private var hasFocus: FocusState<Bool>.Binding

  init(fieldText: Binding<String>, hasFocus: FocusState<Bool>.Binding) {
    self._fieldText = fieldText
    self.hasFocus = hasFocus
  }

  func body(content: Content) -> some View {
    content
      .overlay {
        if !fieldText.isEmpty {
          HStack {
            Spacer()
            Button {
              fieldText = ""
              hasFocus.wrappedValue = true
            } label: {
              Image(systemName: "multiply.circle.fill")
            }
            .foregroundColor(.secondary)
            .padding(.trailing, 4)
          }
        }
      }
  }
}

public extension TextField {
  func clearButton(text: Binding<String>, hasFocus: FocusState<Bool>.Binding) -> some View {
    self.modifier(TextFieldClearButton(fieldText: text, hasFocus: hasFocus))
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
        .clearButton(text: $text, hasFocus: $displayNameFieldIsFocused)
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
