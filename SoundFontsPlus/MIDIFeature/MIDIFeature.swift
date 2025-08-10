// Copyright © 2025 Brad Howes. All rights reserved.

import AUv3Shared
import AudioToolbox
import ComposableArchitecture
import CoreAudioKit
import MorkAndMIDI
import os
import SF2LibAU
import Sharing
import SwiftUI

private let log = Logger(category: "Database")

@Reducer
public struct MIDIFeature {

  @ObservableState
  public struct State: Equatable {
    let midi: MIDI

    public init() {
      @Shared(.midiInputPortId) var midiInputPortId
      self.midi = .init(clientName: "SoundFonts+", uniqueId: Int32(midiInputPortId), midiProto: .legacy)
    }
  }

  public enum Action {
    case foo
  }

  private enum CancelId {
    case monitorMIDI
  }

  public var body: some ReducerOf<Self> {

    Reduce { state, action in
      switch action {
      case .foo: return foo(&state)
      }
    }
  }
}

extension MIDIFeature {

  private func foo(_ state: inout State) -> Effect<Action> {
    return .none
  }
}
