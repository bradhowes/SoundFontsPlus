import AVFAudio.AVAudioSession

public final class AudioSession {
  private var audioEngine: AudioEngine?
  private let volumeMonitor: VolumeMonitor = VolumeMonitor()
  private let log = Logger(category: "AudioSession")
  private var startRequested: Bool = false

  public init(audioEngine: AudioEngine?) {
    self.audioEngine = audioEngine
  }

  /**
   Start audio processing. This is done as the app is brought into the foreground. Note that most of the processing is
   moved to a background thread so as not to block the main thread when app is launching.
   */
  func start() {
    log.debug("startAudioSession BEGIN")

    guard let audioEngine = self.audioEngine else {
      // The synth has not loaded yet, so we postpone until it is.
      log.debug("startAudioSession END - no synth")
      startRequested = true
      return
    }

    DispatchQueue.global(qos: .userInitiated).async { self.startAudioSessionInBackground(audioEngine) }
    log.debug("startAudioSession END")
  }

  private func setAudioEngineInBackground(_ audioEngine: AudioEngine) {
    log.debug("setAudioEngineInBackground BEGIN")
    guard self.audioEngine == nil else { return }

    self.audioEngine = audioEngine

    // If we were started but did not have the synth available, now we can continue starting the audio session.
    if startRequested {
      startRequested = false
      self.startAudioSessionInBackground(audioEngine)
    }

    log.debug("setSynthInBackground END")
  }

  @objc func handleRouteChangeInBackground(notification: Notification) {
    log.debug("handleRouteChangeInBackground BEGIN")
    guard let userInfo = notification.userInfo,
          let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
          let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue)
    else {
      log.debug("handleRouteChangeInBackground END - nothing to see")
      return
    }

    // Switch over the route change reason.
    switch reason {

    case .newDeviceAvailable: // New device found.
      log.debug("handleRouteChangeInBackground - new device available")
      let session = AVAudioSession.sharedInstance()
      dump(route: session.currentRoute)

    case .oldDeviceUnavailable: // Old device removed.
      log.debug("handleRouteChangeInBackground - old device unavailable")
      let session = AVAudioSession.sharedInstance()
      if let previousRoute = userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription {
        dump(route: previousRoute)
        dump(route: session.currentRoute)
      }

    default:
      log.debug("handleRouteChangeInBackground - AVAudioSession.unknown reason - \(reason.rawValue)")
    }
    log.debug("handleRouteChangeInBackground END")
  }

  private func startAudioSessionInBackground(_ audioEngine: AudioEngine) {
    log.debug("startAudioSessionInBackground BEGIN")

    let sampleRate: Double = 44100.0
    let bufferSize: Int = 64
    let session = AVAudioSession.sharedInstance()

    setupAudioSessionNotificationsInBackground()

    do {
      log.debug("startAudioSessionInBackground - setting AudioSession category")
      try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
      log.debug("startAudioSessionInBackground - done")
    } catch let error as NSError {
      log.error(
        "startAudioSessionInBackground - failed to set the audio session category and mode: \(error.localizedDescription)"
      )
    }

    log.debug("startAudioSessionInBackground - sampleRate: \(AVAudioSession.sharedInstance().sampleRate)")
    log.debug("startAudioSessionInBackground - preferredSampleRate: \(AVAudioSession.sharedInstance().sampleRate)")

    do {
      log.debug("startAudioSessionInBackground - setting sample rate")
      try session.setPreferredSampleRate(sampleRate)
      log.debug("startAudioSessionInBackground - done")
    } catch let error as NSError {
      log.error("startAudioSessionInBackground - failed to set the preferred sample rate to \(sampleRate) - \(error.localizedDescription)")
    }

    do {
      log.debug("startAudioSessionInBackground - setting IO buffer duration")
      try session.setPreferredIOBufferDuration(Double(bufferSize) / sampleRate)
      log.debug("startAudioSessionInBackground - done")
    } catch let error as NSError {
      log.error("startAudioSessionInBackground - failed to set the preferred buffer size to \(bufferSize) - \(error.localizedDescription)")
    }

    do {
      log.debug("startAudioSessionInBackground - setting active audio session")
      try session.setActive(true, options: [])
      log.debug("startAudioSessionInBackground - done")
    } catch {
      log.error("startAudioSessionInBackground - failed to set active - \(error.localizedDescription)")
    }

    dump(route: session.currentRoute)

    log.debug("startAudioSessionInBackground - starting synth")
    let result = audioEngine.start()

    DispatchQueue.main.async { self.finishStart(result) }
    log.debug("startAudioSessionInBackground END")
  }

  private func finishStart(_ result: AudioEngine.StartResult) {
    log.debug("finishStart BEGIN - \(result.description)")

    switch result {
    case let .failure(what):
      log.debug("finishStart - failed to start audio session")
      postAlertInBackground(for: what)
    case .success:
      log.debug("finishStart - starting volumeMonitor and MIDI")
      volumeMonitor.start()
    }
    log.error("finishStart - END")
  }

//  private func recreateSynth() {
//    log.error("recreateSynth - BEGIN")
//    stopAudio()
//    start()
//    log.error("recreateSynth - END")
//  }

  private func setupAudioSessionNotificationsInBackground() {
    NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChangeInBackground),
                                           name: AVAudioSession.routeChangeNotification, object: nil)
  }

  private func postAlertInBackground(for what: SynthStartFailure) {
    DispatchQueue.main.async { NotificationCenter.default.post(Notification(name: .synthStartFailure, object: what)) }
  }

  private func dump(route: AVAudioSessionRouteDescription) {
    for input in route.inputs {
      log.debug("AVAudioSession input - \(input.portName)")
    }
    for output in route.outputs {
      log.debug("AVAudioSession output - \(output.portName)")
    }
  }
}
