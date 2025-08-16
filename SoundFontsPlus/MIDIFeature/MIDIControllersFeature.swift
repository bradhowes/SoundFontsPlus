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
    case initialize
  }

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .initialize:
        return initialize(&state)
      }
    }
  }
}

private extension MIDIControllersFeature {
  private func initialize(_ state: inout State) -> Effect<Action> {
    return .none
  }
}

public struct MIDIControllersView: View {
  private var store: StoreOf<MIDIControllersFeature>

  public init(store: StoreOf<MIDIControllersFeature>) {
    self.store = store
  }

  public var body: some View {
    ScrollView {
      LazyVGrid(columns: [
        GridItem(.fixed(40)),
        GridItem(.flexible(minimum: 20, maximum: .infinity)),
        GridItem(.fixed(40)),
        GridItem(.fixed(40)),
        GridItem(.fixed(40))
      ], spacing: 0) {
        Text("ID")
          .frame(maxWidth: .infinity)
          .font(.footnote)
          .foregroundStyle(.secondary)
        Text("Name")
          .font(.footnote)
          .foregroundStyle(.gray)
        Text("Action")
          .font(.footnote)
          .foregroundStyle(.gray)
        Text("Value")
          .font(.footnote)
          .foregroundStyle(.gray)
        Text("Active")
          .font(.footnote)
          .foregroundStyle(.gray)

        Text("1")
        Text("Foo")
          .frame(maxWidth: .infinity)
        Text("blah")
        Text("123")

        //        ForEach(store.rows) { row in
        //          Text("\(row.displayName)")
        //            .frame(maxWidth: .infinity)
        //            .foregroundStyle(animating == row.id ? Color.accentColor : .primary)
        //            .scaleEffect(animating == row.id ? 1.25 : 1.0)
        //
        //          Text(row.channel == 255 ? "-" : "\(row.channel)")
        //            .frame(maxWidth: .infinity)
        //
        //          HStack(spacing: 0) {
        //            Text(row.fixedVolume == 128 ? "Off" : "\(row.fixedVolume)")
        //              .padding([.leading], 8)
        //            Button {
        //              store.send(.fixedVolumeDecrementTapped(row.id))
        //            } label: {
        //              Image(systemName: "arrowtriangle.down")
        //                .frame(width: 30, height: 40)
        //            }
        //            .disabled(row.fixedVolume == 1)
        //            .buttonRepeatBehavior(.enabled)
        //
        //            Button {
        //              store.send(.fixedVolumeIncrementTapped(row.id))
        //            } label: {
        //              Image(systemName: "arrowtriangle.up")
        //                .frame(width: 30, height: 40)
        //            }
        //            .disabled(row.fixedVolume == 128)
        //            .buttonRepeatBehavior(.enabled)
        //          }
        //          .frame(maxWidth: .infinity)
        //
        Button {
          // store.send(.autoConnectToggleTapped(row.id))
        } label: {
          Image(systemName: false ? "checkmark.circle.fill" : "circle")
            .frame(width: 40, height: 40)
        }
        .frame(maxWidth: .infinity)
        //        }
      }
    }
    .padding([.leading, .trailing], 16.0)
    .navigationTitle(Text("Controllers"))
    .task {
      await store.send(.initialize).finish()
    }
  }
}
