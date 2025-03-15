// Copyright © 2025 Brad Howes. All rights reserved.

import SwiftUI

// Solution below from https://stackoverflow.com/a/76412638/629836

// Conform to `PrimitiveButtonStyle` for custom interaction behaviour
struct SupportsLongPress: PrimitiveButtonStyle {

  /// An action to execute on long press
  let longPressAction: () -> ()

  /// Whether the button is being pressed
  @State var isPressed: Bool = false

  public func makeBody(configuration: Configuration) -> some View {

    // The "label" as specified when declaring the button
    configuration.label
      // .brightness(self.isPressed ? 0.1 : 0)
      .background(self.isPressed ? Color.gray : Color.clear)
    // Visual feedback that the button is being pressed
      // .scaleEffect(self.isPressed ? 0.9 : 1.0)

      .onTapGesture {
        // Run the "action" as specified
        // when declaring the button
        configuration.trigger()
      }

      .onLongPressGesture(perform: {
        // Run the action specified
        // when using this style
        self.longPressAction()
      }, onPressingChanged: { pressing in
        // Use "pressing" to infer whether the button
        // is being pressed
        print("pressing")
        self.isPressed = pressing
      })
  }
}

/// A modifier that applies the `SupportsLongPress` style to buttons
struct SupportsLongPressModifier: ViewModifier {
  let longPressAction: () -> ()
  func body(content: Content) -> some View {
    content.buttonStyle(SupportsLongPress(longPressAction: self.longPressAction))
  }
}

/// Extend the View protocol for a SwiftUI-like shorthand version
extension View {
  public func supportsLongPress(longPressAction: @escaping () -> ()) -> some View {
    modifier(SupportsLongPressModifier(longPressAction: longPressAction))
  }
}

// --- At the point of use:

//struct MyCustomButtonRoom: View {
//
//  var body: some View {
//
//    Button(
//      action: {
//        print("You've tapped me!")
//      },
//      label: {
//        Text("Do you dare interact?")
//      }
//    )
//    .supportsLongPress {
//      print("Looks like you've pressed me.")
//    }
//
//  }
//
//}

//public struct LongPressModifier: ViewModifier {
//  @GestureState private var isDetectingLongPress = false
//  let action: () -> Void
//
//  var longPress: some Gesture {
//    LongPressGesture(minimumDuration: 1)
//      .updating($isDetectingLongPress) { currentState, gestureState, transaction in
//        gestureState = currentState
//        transaction.animation = Animation.easeIn(duration: 2.0)
//      }
//      .onEnded { finished in
//        if finished {
//          action()
//        }
//      }
//  }
//
//  public func body(content: Content) -> some View {
//    content
//      .frame(maxWidth: .infinity, alignment: .leading)
//      .contentShape(Rectangle())
//      .simultaneousGesture(longPress)
//  }
//}
//
//extension View {
//  public func onCustomLongPressGesture(_ action: @escaping () -> Void) -> some View {
//    modifier(LongPressModifier(action: action))
//  }
//}
