// Copyright © 2025 Brad Howes. All rights reserved.

import SwiftUI

/**
 Custom view that presents content in a SwiftUI `List` view with desired styling.

 This container is used to show the soundfonts, presets, and tags.
 */
public struct StyledList<Content: View>: View {
  private let content: Content

  public init(@ViewBuilder _ content: () -> Content) {
    self.content = content()
  }

#if os(iOS)
  public var body: some View {
    List {
      content
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
    .listStyle(.plain)
    .listSectionSpacing(0)
    // .background(.green)
  }
#endif // os(iOS)

#if os(macOS)
  public var body: some View {
    List {
      content
        .listRowSeparator(.hidden)
    }
    .listStyle(.plain)
  }
#endif // os(macOS)
}

/**
 Custom view that presents an item in a ``StyledList`` view with desired styling.

 Currently, there are no customizations being applied to the content.
 */
public struct StyledEntry<Content: View>: View {
  private let content: Content

  public init(@ViewBuilder _ content: () -> Content) {
    self.content = content()
  }

  public var body: some View {
    content
  }
}

/**
 Custom view that presents a header in a sectioned list.

 The presets list view has multiple sections; the soundfonts and tags list views only have one that serves as the title.
 */
public struct StyledHeader<Content: View>: View {
  private let content: Content

  public init(@ViewBuilder _ content: () -> Content) {
    self.content = content()
  }

  public var body: some View {
    content
      .frame(maxWidth: .infinity, alignment: .leading)
      .foregroundStyle(Color.listHeaderText)
  }
}

#if DEBUG

#Preview {
  @Previewable @State var selected = 0
  StyledList {
    ForEach(0...5, id: \.self) { section in
      Section {
        let entries = (section * 5)..<(section * 5 + 5)
        ForEach(entries, id: \.self) { entry in
          StyledEntry {
            HStack {
              Button("Hello \(entry)") { selected = entry }
              Spacer()
              Text("\(entry)")
            }
          }
          .indicator(entry == selected ? .active : .none)
        }
      } header: {
        StyledHeader { Text("Section \(section)") }
      }
    }
  }
}

#endif // DEBUG
