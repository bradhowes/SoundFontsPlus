// Copyright © 2024 Brad Howes. All rights reserved.

import ComposableArchitecture
import SwiftUI
import Models

public struct TagButtonView: View {
  let name: String
  let tag: TagModel.Key
  let isActive: Bool
  let activateAction: (TagModel.Key) -> Void
  let deleteAction: ((TagModel.Key) -> Void)?
  @State var isPresented: Bool = false

  public init(
    name: String,
    tag: TagModel.Key,
    isActive: Bool,
    activateAction: @escaping (TagModel.Key) -> Void,
    deleteAction: ((TagModel.Key) -> Void)?
  ) {
    self.name = name
    self.tag = tag
    self.isActive = isActive
    self.activateAction = activateAction
    self.deleteAction = deleteAction
  }

  public var body: some View {
    Button {
      activateAction(tag)
    } label: {
      Text(name)
        .indicator(isActive)
    }
    .swipeActions {
      if deleteAction != nil {
        Button {
          isPresented = true
        } label: {
          Label("Delete", systemImage: "trash")
            .tint(.red)
        }
      }
    }
    .confirmationDialog(
      "Are you sure you want to delete tag \(name)?",
      isPresented: $isPresented,
      titleVisibility: .visible,
      presenting: tag
    ) { tag in
      Button("Confirm", role: .destructive) {
        deleteAction?(tag)
      }
      Button("Cancel", role: .cancel) {
        isPresented = false
      }
    }
  }
}

#Preview {
  List {
    TagButtonView(
      name: "Inactive Foobar",
      tag: .init(.init(0)),
      isActive: true,
      activateAction: {_ in},
      deleteAction: nil
    )
    TagButtonView(
      name: "Active Blah",
      tag: .init(.init(1)),
      isActive: false,
      activateAction: {_ in},
      deleteAction: nil
    )
    .onCustomLongPressGesture {
      print("long press")
    }
  }
}
