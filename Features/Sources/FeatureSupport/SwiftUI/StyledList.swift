// Copyright © 2025 Brad Howes. All rights reserved.

import SwiftUI

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

public struct StyledEntry<Content: View>: View {
  private let content: Content
  @State private var visible: Bool

  public init(@ViewBuilder _ content: () -> Content) {
    self.content = content()
    self.visible = true
  }

  public var body: some View {
    content
      .onGeometryChange(for: Bool.self) {
        $0.frame(in: .global).origin.y > 40.0
      } action: {
        visible = $0
      }
      .opacity(visible ? 1.0 : 0.0)
  }
}

public struct StyledHeader<Content: View>: View {
  private let content: Content

  public init(@ViewBuilder _ content: () -> Content) {
    self.content = content()
  }

  public var body: some View {
    content
      .frame(
        minWidth: 0,
        maxWidth: .infinity,
        minHeight: 0,
        maxHeight: .infinity,
        alignment: .topLeading
      )
      .padding([.top, .bottom, .leading], 8)
      // .background(.black)
      .foregroundStyle(Color.listHeaderText)
      .offset(x: -16)
  }
}

#if DEBUG

#Preview {
  StyledList {
    ForEach(0...5, id: \.self) { section in
      Section {
        let entries = (section * 5)..<(section * 5 + 5)
        ForEach(entries, id: \.self) { entry in
          StyledEntry {
            HStack {
              Text("Hello \(entry)")
                .indicator(.active)
              Spacer()
              Text("\(entry)")
            }
          }
        }
      } header: {
        StyledHeader { Text("Section \(section)") }
      }
    }
  }
}

#endif // DEBUG
