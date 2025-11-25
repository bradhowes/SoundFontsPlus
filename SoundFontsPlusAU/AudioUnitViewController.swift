// Copyright © 2025 Brad Howes. All rights reserved.

import Combine
import CoreAudioKit
import os
import Sharing
import SwiftUI
import Synth

@MainActor
public class AudioUnitViewController: AUViewController, AUAudioUnitFactory {
  var audioUnit: AUAudioUnit?

  // var hostingController: HostingController<SoundFontsPlusAUMainView>?

  private var observation: NSKeyValueObservation?

  /* iOS View lifcycle
   public override func viewWillAppear(_ animated: Bool) {
   super.viewWillAppear(animated)

   // Recreate any view related resources here..
   }

   public override func viewDidDisappear(_ animated: Bool) {
   super.viewDidDisappear(animated)

   // Destroy any view related content here..
   }
   */

  /* macOS View lifcycle
   public override func viewWillAppear() {
   super.viewWillAppear()

   // Recreate any view related resources here..
   }

   public override func viewDidDisappear() {
   super.viewDidDisappear()

   // Destroy any view related content here..
   }
   */

  deinit {}

  public override func viewDidLoad() {
    super.viewDidLoad()
    if let audioUnit {
      configureSwiftUIView(audioUnit: audioUnit)
    }
  }

  /**
   Implementation of `AUAudioUnitFactory` method that creates a new `AUAudioUnit` for the view controller to manage.

   - parameter componentDescription: what AUv3 component to instantiate
   - returns new AUAudioUnit instance
   */
  nonisolated public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
    return try DispatchQueue.main.sync {
      @Shared(.auAudioUnit) var auAudioUnit
      let audioUnit = try SF2LibAU(componentDescription: componentDescription, options: [])
      $auAudioUnit.withLock { $0 = audioUnit }

      self.audioUnit = audioUnit
      DispatchQueue.main.async { [weak self] in
        self?.configureSwiftUIView(audioUnit: audioUnit)
      }
      return audioUnit
    }
  }

  private func configureSwiftUIView(audioUnit: AUAudioUnit) {
//    if let host = hostingController {
//      host.removeFromParent()
//      host.view.removeFromSuperview()
//    }
//
//    guard let observableParameterTree = audioUnit.observableParameterTree else {
//      return
//    }
//    let content = SoundFontsPlusAUMainView(parameterTree: observableParameterTree)
//    let host = HostingController(rootView: content)
//    self.addChild(host)
//    host.view.frame = self.view.bounds
//    self.view.addSubview(host.view)
//    hostingController = host
//
//    // Make sure the SwiftUI view fills the full area provided by the view controller
//    host.view.translatesAutoresizingMaskIntoConstraints = false
//    host.view.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
//    host.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor).isActive = true
//    host.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor).isActive = true
//    host.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
//    self.view.bringSubviewToFront(host.view)
  }

}

private let log = Logger(
  subsystem: "com.braysoftware.SoundFontsPlus.SoundFontsPlusAU",
  category: "AudioUnitViewController"
)
