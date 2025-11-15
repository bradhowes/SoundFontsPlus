import AVFAudio
import BaseSupport
import ComposableArchitecture
import Dependencies
import VolumeMonitor
import SwiftUI

struct ContentView: View {
  @State private var store: StoreOf<VolumeMonitor>

  public init(store: StoreOf<VolumeMonitor>) {
    let audioFormat: AVAudioFormat! = AVAudioFormat(
      commonFormat: .pcmFormatFloat32,
      sampleRate: 48_000.0,
      channels: 2,
      interleaved: false
    )

    @Dependency(\.audioSession) var audioSession
    let result = audioSession.start(audioFormat)
    print("audioSession.start:", result)
    self.store = store
  }

  var body: some View {
    VStack {
      Image(systemName: "globe")
        .imageScale(.large)
        .foregroundStyle(.tint)
      Text("Hello, world!")
      Text("Reason: \(store.reason.debugDescription)")
    }
    .task {
      await store.send(.initialize).finish()
    }
    .padding()
    .volumeMonitorHUD(store: self.store)
  }
}

#Preview {
  ContentView(store: .init(initialState: VolumeMonitor.State()) {
    VolumeMonitor()
  })
}
