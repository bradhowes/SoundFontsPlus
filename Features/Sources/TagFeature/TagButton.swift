// Copyright © 2024 Brad Howes. All rights reserved.

import ComposableArchitecture
import SwiftUI
import Models

/**
 A button view for a tag. Pressing it updates the collection of `SoundFont` models that are shown.
 */
struct TagButtonView: View {
  let name: String
  let tag: UUID
  let activator: () -> Void

  @Shared(.activeTag) var activeTag
  var isActive: Bool { activeTag == tag }

  init(
    name: String,
    tag: UUID,
    activator: @escaping () -> Void
  ) {
    self.name = name
    self.tag = tag
    self.activator = activator
  }

  var body: some View {
    Button {
      activator()
    } label: {
      Text(name)
        .indicator(isActive)
    }
  }
}

#Preview {
  @Shared(.activeTag) var activeTag
  List {
    TagButtonView(
      name: "Inactive Foobar",
      tag: UUID(0),
      activator: { activeTag = UUID(0) }
    )
    TagButtonView(
      name: "Active Blah",
      tag: UUID(1),
      activator: { activeTag = UUID(1) }
    )
    .onCustomLongPressGesture {
      print("long press")
    }
  }
}

struct IndicatorModifier: ViewModifier {
  let shown: Bool

  private var indicatorWidth: CGFloat { 6 }
  private var cornerRadius: CGFloat { indicatorWidth / 2.0 }
  private var offset: CGFloat { -2.0 * indicatorWidth }
  private var indicator: Color { shown ? .indigo : .clear }
  private var labelColor: Color { shown ? .indigo : .blue }

  func body(content: Content) -> some View {
    ZStack(alignment: .leading) {
      Rectangle()
        .fill(indicator.gradient)
        .frame(width: indicatorWidth)
        .cornerRadius(cornerRadius)
        .offset(x: offset)
        .animation(.linear(duration: 0.5), value: indicator)
      content
        .font(.headline)
        .foregroundStyle(labelColor)
        .animation(.linear(duration:0.5), value: labelColor)
    }
  }
}

struct LongPressModifier: ViewModifier {
  @GestureState private var isDetectingLongPress = false
  let action: () -> Void

  var longPress: some Gesture {
    LongPressGesture(minimumDuration: 1)
      .updating($isDetectingLongPress) { currentState, gestureState, transaction in
        gestureState = currentState
        transaction.animation = Animation.easeIn(duration: 2.0)
      }
      .onEnded { finished in
        if finished {
          action()
        }
      }
  }

  func body(content: Content) -> some View {
    content
      .simultaneousGesture(longPress)
  }
}

extension View {
  public func indicator(_ shown: Bool) -> some View {
    modifier(IndicatorModifier(shown: shown))
  }

  public func onCustomLongPressGesture(_ action: @escaping () -> Void) -> some View {
    modifier(LongPressModifier(action: action))
  }
}
