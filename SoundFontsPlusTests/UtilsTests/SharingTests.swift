import ComposableArchitecture
import Sharing
import SnapshotTesting
import SwiftUI
import Testing

@testable import SoundFontsPlus

extension BaseTestSuite {

  @MainActor
  struct SharingTests {}
}

extension BaseTestSuite.SharingTests {

  @Test func boolValues() {
    boolChecker(.backgroundProcessing)
    boolChecker(.copyFileWhenInstalling)
    boolChecker(.delayLockEnabled)
    boolChecker(.delayLockEnabled)
    boolChecker(.disableIdleTimer)
    boolChecker(.effectsVisible)
    boolChecker(.favoritesOnTop)
    boolChecker(.globalTuningEnabled)
    boolChecker(.keyboardSlides)
    boolChecker(.midiAutoConnect)
    boolChecker(.playSoundOnPresetChange)
    boolChecker(.reverbLockEnabled)
    boolChecker(.showKeyNotes)
    boolChecker(.showActiveVoiceCount)
    boolChecker(.showOnlyFavorites)
    boolChecker(.showSolfegeTags)
    boolChecker(.showedTutorial)
    boolChecker(.starFavoriteNames)
    boolChecker(.tagsListVisible)
    boolChecker(.confirmPresetHiding)
  }

  @Test func doubleValues() {
    doubleChecker(.fontsAndPresetsSplitPosition)
    doubleChecker(.fontsAndTagsSplitPosition)
    doubleChecker(.globalTuning)
    doubleChecker(.keyWidth)
  }

  @Test func intValues() {
    intChecker(.midiChannel)
    intChecker(.midiInputPortId)
    intChecker(.pitchBendRange)
  }

  @Test func stringValues() {
    stringChecker(.lastReviewRequestVersion)
    stringChecker(.lastShowedChangesVersion)
  }

  @Test func customValues() {
    @Shared(.keyLabels) var value1
    let initValue1 = value1
    $value1.withLock { $0 = .all }
    #expect(value1 != initValue1)

    @Shared(.firstVisibleKey) var value2
    let initValue2 = value2
    $value2.withLock { $0 = .A4 }
    #expect(value2 != initValue2)

    @Shared(.selectedSoundFontId) var value3
    #expect(value3 == nil)
    $value3.withLock { $0 = 1 }
    #expect(value3 != nil)
  }

  func boolChecker(_ key: AppStorageKey<Bool>.Default) {
    @Shared(key) var value
    let initValue = value
    $value.withLock { $0.toggle() }
    #expect(value != initValue)
  }

  func doubleChecker(_ key: AppStorageKey<Double>.Default) {
    @Shared(key) var value
    let initValue = value
    $value.withLock { $0 += 1.0 }
    #expect(value != initValue)
  }

  func intChecker(_ key: AppStorageKey<Int>.Default) {
    @Shared(key) var value
    let initValue = value
    $value.withLock { $0 += 1 }
    #expect(value != initValue)
  }

  func stringChecker(_ key: AppStorageKey<String>.Default) {
    @Shared(key) var value
    let initValue = value
    $value.withLock { $0 += "testing" }
    #expect(value != initValue)
  }
}
