import AVFAudio

extension AVAudioUnitDelay {

  public func setConfig(_ config: DelayConfig.Draft) {
    self.delayTime = config.time
    self.feedback = Float(config.feedback)
    self.lowPassCutoff = Float(config.cutoff)
    self.wetDryMix = Float(config.wetDryMix)
    self.bypass = !config.enabled
  }
}
