// Copyright © 2025 Brad Howes. All rights reserved.

import AUv3Root
import CoreAudioKit
import FeatureSupport
import os
import Sharing
import SwiftUI
import SF2LibAU

/**
 Custom AUViewController for the SoundFontsPlus AUv3 component. The construction process for an AUv3 component always results in an
 instance of this, including the AUv3 component that is instantiated by the app -- the AUv3RootView is ignored in that case as the
 AppRootView controls the AUv3 component.
 */
@MainActor
public class AudioUnitViewController: AUViewController, AUAudioUnitFactory {
  public var audioUnit: SF2LibAU?
  public var hostingController: AUv3HostingController<AUv3RootView>?

  deinit {}

  public override func viewDidLoad() {
    log.info("viewDidLoad BEGIN")
    installApplicationFont()
    super.viewDidLoad()
    if let audioUnit {
      installView(audioUnit: audioUnit)
    }
    log.info("viewDidLoad END")
  }

  /**
   Implementation of `AUAudioUnitFactory` method that creates a new `AUAudioUnit` for a view controller to manage.

   - parameter componentDescription: what AUv3 component to instantiate
   - returns: new AUAudioUnit instance
   */
  nonisolated public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
    log.info("createAudioUnit BEGIN")
    @Shared(.isAUv3) var isAUv3
    $isAUv3.withLock { $0 = true }

    prepareDependencies {
      if ProcessInfo.processInfo.environment["UITesting"] == "true" {
        $0.defaultFileStorage = .inMemory
      } else {
        $0.defaultFileStorage = .fileSystem
      }

      // swiftlint:disable:next force_try
      $0.defaultDatabase = try! appDatabase()

      try? $0.fileManager.createDirectory($0.fileManager.fontFilesDirectory())
    }

    log.info("createAudioUnit END")

    return try DispatchQueue.main.sync {
      let audioUnit = try SF2LibAU(componentDescription: componentDescription, options: [])
      DispatchQueue.main.async { [weak self] in
        self?.installView(audioUnit: audioUnit)
      }
      return audioUnit
    }
  }

  private func installView(audioUnit: SF2LibAU) {
    log.info("installView BEGIN")
    if let host = hostingController {
      host.removeFromParent()
      host.view.removeFromSuperview()
    }

    // Entry point for AUv3 view
    let store = AUv3Root.make(audioUnit: audioUnit)
    let content = AUv3RootView(store: store)
    let host = AUv3HostingController(rootView: content)

    audioUnit.fullStateChanged = {
      DispatchQueue.main.async {
        store.send(.fullStateChanged)
      }
    }

    self.addChild(host)
    host.view.frame = self.view.bounds
    self.view.addSubview(host.view)

    self.audioUnit = audioUnit
    self.hostingController = host

    // Make sure the SwiftUI view fills the full area provided by the view controller
    host.view.translatesAutoresizingMaskIntoConstraints = false
    host.view.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
    host.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor).isActive = true
    host.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor).isActive = true
    host.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
#if os(iOS)
    host.view.backgroundColor = .clear
    self.view.backgroundColor = .black
    self.view.bringSubviewToFront(host.view)
#endif
    log.info("installView END")
  }
}

#if os(iOS) || os(visionOS)

public typealias AUv3HostingController = UIHostingController

#elseif os(macOS)

public typealias AUv3HostingController = NSHostingController

#endif

private let log: Logger = .init(category: "AudioUnitViewController", loggingSubsystemValue: .loggingSubsystemAUv3Value)
