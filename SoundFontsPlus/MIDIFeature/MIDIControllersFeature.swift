// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import CoreMIDI
import Sharing
import SwiftUI

@Reducer
public struct MIDIControllersFeature {

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

private extension MIDIControllersFeature {
}

public struct MIDIControllersView: View {
  private var store: StoreOf<MIDIControllersFeature>

  public init(store: StoreOf<MIDIControllersFeature>) {
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
