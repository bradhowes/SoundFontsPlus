// Copyright © 2025 Brad Howes. All rights reserved.

import AUv3Root
import Combine
import CoreAudioKit
import FeatureSupport
import os
import Sharing
import SwiftUI
import SF2LibAU

@MainActor
public class AudioUnitViewController: AUViewController, AUAudioUnitFactory {
  public var audioUnit: SF2LibAU?
  public var hostingController: AUv3HostingController<AUv3RootView>?

  deinit {}

  public override func viewDidLoad() {
    super.viewDidLoad()
    if let audioUnit {
      installView(audioUnit: audioUnit)
    }
  }

  /**
   Implementation of `AUAudioUnitFactory` method that creates a new `AUAudioUnit` for the view controller to manage.

   - parameter componentDescription: what AUv3 component to instantiate
   - returns new AUAudioUnit instance
   */
  nonisolated public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
    try DispatchQueue.main.sync {
      AUv3Root.prepareDependencies()
      @Shared(.auAudioUnit) var auAudioUnit
      let audioUnit = try SF2LibAU(componentDescription: componentDescription, options: [])
      $auAudioUnit.withLock { $0 = audioUnit }

      self.audioUnit = audioUnit
      DispatchQueue.main.async { [weak self] in
        self?.installView(audioUnit: audioUnit)
      }
      return audioUnit
    }
  }

  private func installView(audioUnit: AUAudioUnit) {

    if let host = hostingController {
      host.removeFromParent()
      host.view.removeFromSuperview()
    }

    let content = AUv3RootView(store: Store(initialState: .init()) { AUv3Root() })
    let host = AUv3HostingController(rootView: content)
    self.addChild(host)
    host.view.frame = self.view.bounds
    self.view.addSubview(host.view)
    hostingController = host

    // Make sure the SwiftUI view fills the full area provided by the view controller
    host.view.translatesAutoresizingMaskIntoConstraints = false
    host.view.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
    host.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor).isActive = true
    host.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor).isActive = true
    host.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
    self.view.bringSubviewToFront(host.view)
  }
}

#if os(iOS) || os(visionOS)

public typealias AUv3HostingController = UIHostingController

#elseif os(macOS)

public typealias AUv3HostingController = NSHostingController

#endif

private let log = Logger(
  subsystem: "com.braysoftware.SoundFontsPlus.SoundFontsPlusAU",
  category: "AudioUnitViewController"
)
