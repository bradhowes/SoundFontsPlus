// Copyright © 2025 Brad Howes. All rights reserved.

import SwiftUI

/**
 Customized `TextField` that shows a dark background to indicate that it is editable.
 */
public struct NameFieldView: View {
  private var text: Binding<String>
  private let readOnly: Bool
  private var editable: Bool { !readOnly }

#if os(iOS)
  @Environment(\.editMode) private var editMode
  private var isEditing: Bool { editMode?.wrappedValue.isEditing == true }
#else
  private var isEditing: Bool { false }
#endif

  public init(text: Binding<String>, readOnly: Bool) {
    self.text = text
    self.readOnly = readOnly
  }

  public var body: some View {
    textField
      .disabled(readOnly || isEditing)
      .deleteDisabled(readOnly)
      .foregroundStyle(editable ? .primary : .secondary)
      .font(Font.custom(Font.applicationFontName, size: 20))
  }

  @ViewBuilder
  public var textField: some View {
    if readOnly {
      readonlyTextField
    } else {
      editableTextField
    }
  }

  private var readonlyTextField: some View {
    TextField("", text: text)
  }

  private var editableTextField: some View {
    TextField("", text: text)
      .textFieldStyle(.roundedBorder)
  }
}
