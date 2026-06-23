// Copyright © 2026 Brad Howes. All rights reserved.

import Foundation

/**
 Utility that checks for changes in a user-defined state.

 Holds a closure that creates the current state. The `changed` method creates a new state representation and returns `true` if the
 values differ (updating the held representation with the new one).
 */
public struct StateMonitor<State: Equatable> {
  private let make: () -> State
  private var state: State

  public init(make: @escaping () -> State) {
    self.make = make
    self.state = make()
  }

  mutating public func changed() -> Bool {
    let newState = make()
    defer { state = newState }
    return state != newState
  }
}
