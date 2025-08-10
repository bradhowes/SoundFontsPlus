// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import CoreMIDI
import Sharing
import SwiftUI

@Reducer
public struct MIDIAssignmentsFeature {

  @ObservableState
  public struct State: Equatable, Sendable {
  }

  public enum Action: Equatable, Sendable {
  }

  public var body: some ReducerOf<Self> {
    Reduce { _, action in
      switch action {
      }
    }
  }
}

private extension MIDIAssignmentsFeature {
}

public struct MIDIAssignmentsView: View {
  private var store: StoreOf<MIDIAssignmentsFeature>

  public init(store: StoreOf<MIDIAssignmentsFeature>) {
    self.store = store
  }

  public var body: some View {
    List {
//      ForEach(store.sources) { item in
//        Text("\(item.displayName)")
//      }
    }
  }
}
