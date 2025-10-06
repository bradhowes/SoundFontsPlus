import AVFAudio

extension AVAudioUnit {
  var synth: SF2LibAU? { self.auAudioUnit as? SF2LibAU }
}
