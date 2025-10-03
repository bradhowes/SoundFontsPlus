// Copyright © 2025 Brad Howes. All rights reserved.

import AUv3Controls
import AVFoundation
import SwiftUI

struct ReverbRoomPresetPickerView: View {
  @State var value: AVAudioUnitReverbPreset = .mediumHall
  @Environment(\.auv3ControlsTheme) var theme

  var body: some View {
    Picker("Room", selection: $value) {
      ForEach(AVAudioUnitReverbPreset.allCases, id: \.self) { room in
        Text(room.name).tag(room)
          .font(theme.font)
          .foregroundStyle(theme.textColor)
      }
    }
    .pickerStyle(.wheel)
    .frame(width: 110)  // !!! Magic size that fits all of the strings without wasted space
  }
}
