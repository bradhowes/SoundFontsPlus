// Copyright © 2024 Brad Howes. All rights reserved.

import ComposableArchitecture
import SwiftUI
import Models

public struct TagButtonView: View {
  let name: String
  let key: TagModel.Key
  let isActive: Bool
  let activateAction: (TagModel.Key) -> Void
  let deleteAction: ((TagModel.Key) -> Void)?
  @State var confirmingTagDeletion: Bool = false

  public init(
    name: String,
    key: TagModel.Key,
    isActive: Bool,
    activateAction: @escaping (TagModel.Key) -> Void,
    deleteAction: ((TagModel.Key) -> Void)?
  ) {
    self.name = name
    self.key = key
    self.isActive = isActive
    self.activateAction = activateAction
    self.deleteAction = deleteAction
  }

  public var body: some View {
    Button {
      activateAction(key)
    } label: {
      Text(name)
        .indicator(isActive)
    }
    .swipeToDeleteTag(
      enabled: deleteAction != nil,
      showingConfirmation: $confirmingTagDeletion,
      key: key,
      name: name) {
        deleteAction?(key)
      }
  }
}

#Preview {
  List {
    TagButtonView(
      name: "Inactive Foobar",
      key: .init(.init(0)),
      isActive: true,
      activateAction: {_ in},
      deleteAction: nil
    )
    TagButtonView(
      name: "Active Blah",
      key: .init(.init(1)),
      isActive: false,
      activateAction: {_ in},
      deleteAction: nil
    )
    .onCustomLongPressGesture {
      print("long press")
    }
  }
}
