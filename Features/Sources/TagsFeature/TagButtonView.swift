// Copyright © 2024 Brad Howes. All rights reserved.

import ComposableArchitecture
import SwiftUI
import Models

/**
 A button view for a tag. Pressing it updates the collection of `SoundFont` models that are shown.
 */
public struct TagButtonView: View {
  let name: String
  let tag: UUID
  let isActive: Bool
  let activator: () -> Void

  public init(
    name: String,
    tag: UUID,
    isActive: Bool,
    activator: @escaping () -> Void
  ) {
    self.name = name
    self.tag = tag
    self.isActive = isActive
    self.activator = activator
  }

  public var body: some View {
    Button {
      activator()
    } label: {
      Text(name)
        .indicator(isActive)
    }
  }
}

#Preview {
  List {
    TagButtonView(
      name: "Inactive Foobar",
      tag: UUID(0),
      isActive: true,
      activator: {}
    )
    TagButtonView(
      name: "Active Blah",
      tag: UUID(1),
      isActive: false,
      activator: {}
    )
    .onCustomLongPressGesture {
      print("long press")
    }
  }
}

