import AVFAudio

extension AVAudioUnitDelay {

  public func getConfig() -> DelayConfig.Draft {
    .init(
      id: nil,
      time: self.delayTime,
      feedback: Double(self.feedback),
      cutoff: Double(self.lowPassCutoff),
      wetDryMix: Double(self.wetDryMix),
      enabled: !self.bypass,
      presetId: nil
    )
  }

  public func setConfig(_ config: DelayConfig.Draft) {
    self.delayTime = config.time
    self.feedback = Float(config.feedback)
    self.lowPassCutoff = Float(config.cutoff)
    self.wetDryMix = Float(config.wetDryMix)
    self.bypass = !config.enabled
  }
}
