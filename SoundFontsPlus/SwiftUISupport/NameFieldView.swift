import SwiftUI

/**
 Customized `TextField` that shows a dark background to indicate that it is editable.
 */
public struct NameFieldView: View {
  private var text: Binding<String>
  private let readOnly: Bool
  @Environment(\.editMode) private var editMode
  private var editable: Bool { !readOnly }
  private var isEditing: Bool { editMode?.wrappedValue.isEditing == true }

  public init(text: Binding<String>, readOnly: Bool) {
    self.text = text
    self.readOnly = readOnly
  }

  public var body: some View {
    let backgroundColor: Color = readOnly ? .clear : .init(hex: "202020")!
    return ZStack {
      RoundedRectangle(cornerRadius: 8)
        .padding(.init(top: 0, leading: -4, bottom: 0, trailing: 4))
        .foregroundStyle(backgroundColor)
      TextField("", text: text)
        .disabled(readOnly || isEditing)
        .deleteDisabled(readOnly)
        .foregroundStyle(editable ? .white : .secondary)
        .font(Font.custom("Eurostile", size: 20))
    }
  }
}
