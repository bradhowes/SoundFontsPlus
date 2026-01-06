// Copyright © 2025 Brad Howes. All rights reserved.

import CoreMIDI
import FeatureSupport

@Reducer
public struct MIDIAssignments {

  @ObservableState
  public struct State: Equatable {
    public init() {}
  }

  @frozen
  public enum Action {
    case initialize
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .initialize:
        return initialize(&state)
      }
    }
  }
}

private extension MIDIAssignments {
  private func initialize(_ state: inout State) -> Effect<Action> {
    return .none
  }
}

public struct MIDIAssignmentsView: View {
  private var store: StoreOf<MIDIAssignments>

  public init(store: StoreOf<MIDIAssignments>) {
    self.store = store
  }

  public var body: some View {
    ScrollView {
      LazyVGrid(columns: [
        GridItem(.flexible(minimum: 20, maximum: .infinity)),
        GridItem(.flexible(minimum: 20, maximum: .infinity))
      ], spacing: 0) {
        Text("Action")
          .frame(maxWidth: .infinity)
          .font(.footnote)
          .foregroundStyle(.secondary)
        Text("Controller")
          .font(.footnote)
          .foregroundStyle(.gray)

        Text("Reverb On/Off")
          .frame(maxWidth: .infinity)
        Text("CC 113 Forget")
          .frame(maxWidth: .infinity)

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
    .navigationTitle(Text("MIDI Assignments"))
    .task {
      await store.send(.initialize).finish()
    }
  }
}

extension MIDIAssignmentsView {
  static var preview: some View {
    prepareDependencies {
      $0.defaultDatabase = previewDatabase()
    }
    navigationBarTitleStyle()
    return VStack {
      MIDIAssignmentsView(
        store: Store(initialState: .init()) {
          MIDIAssignments()
        }
      )
    }
  }
}

#Preview {
  MIDIAssignmentsView.preview
}
