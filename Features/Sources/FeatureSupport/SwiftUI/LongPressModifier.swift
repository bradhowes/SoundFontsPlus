// Copyright © 2025 Brad Howes. All rights reserved.

import SwiftUI

/**
 Custom view modifier for long-press gesture that also supports other gestures such as taps.
 */
public struct SimultaneousLongPressGestureModifier: ViewModifier {
  private let minimumDuration: Double
  private let action: () -> Void

  /**
   Configure long-press gesture to call `action` after `minimumDuration` seconds have passed while pressed.

   - parameter minimumDuration: the duration of the gesture
   - parameter action: the closure to invoke
   */
  public init(minimumDuration: Double, action: @escaping () -> Void) {
    self.minimumDuration = minimumDuration
    self.action = action
  }

  public func body(content: Content) -> some View {
    content
      .simultaneousGesture(LongPressGesture(minimumDuration: minimumDuration).onEnded { _ in action() })
  }
}

extension View {

  /**
   Add a simultaneous long-press gesture to a view.

   - parameter minimumDuration: the duration of the long press required to invoke the action
   - parameter action: the closure to invoke
   - returns: the modified view
   */
  public func withLongPressGesture(minimumDuration: Double = 0.75, _ action: @escaping () -> Void) -> some View {
    modifier(SimultaneousLongPressGestureModifier(minimumDuration: minimumDuration, action: action))
  }
}

#if DEBUG

struct LongPressGestureModifierPreview: View {
  @State var msg: String = ""

  var body: some View {
    List {
      ForEach(1..<6) { index in
        Button("Button \(index)") { setMsg("button \(index) tapped") }
          .withLongPressGesture { setMsg("button \(index) long press") }
      }
    }
    Text(msg)
  }

  func setMsg(_ value: String) {
    self.msg = value
  }
}

#Preview {
  LongPressGestureModifierPreview()
}

#endif // DEBUG
