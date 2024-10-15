// Copyright © 2024 Brad Howes. All rights reserved.

import SwiftUI

public struct LongPressModifier: ViewModifier {
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

  public func body(content: Content) -> some View {
    content
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(Rectangle())
      .simultaneousGesture(longPress)
  }
}

extension View {
  public func onCustomLongPressGesture(_ action: @escaping () -> Void) -> some View {
    modifier(LongPressModifier(action: action))
  }
}
