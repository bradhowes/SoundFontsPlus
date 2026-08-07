// Copyright © 2025 Brad Howes. All rights reserved.

public import ComposableArchitecture
import FeatureSupport
import FileImporter
import Keyboard
import MIDITrafficIndicator
public import SwiftUI

public struct ToolBarView: View {
  private var store: StoreOf<ToolBar>
  @Shared(.favoriteSymbolName) private var favoriteSymbolName
  @Shared(.showActiveVoiceCount) private var showActiveVoiceCount
  @Shared(.showMIDITrafficIndicator) private var showMIDITrafficIndicator

  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.controlSpacing) private var controlSpacing

  private var keyboardControlSpacing: CGFloat { controlSpacing - 2 }
  private var keyboardShiftButtonWidth: CGFloat { 28 }
  private let maxCompactBarWidth: CGFloat = 440 // iPhone 17 Pro Max
  private let rowHeight: CGFloat = 28
  private let isAUv3: Bool

  private var isApp: Bool { !isAUv3 }
  private var height: CGFloat { rowHeight }

  @State private var animationState: AnimationState = .init()

  public init(store: StoreOf<ToolBar>, isAUv3: Bool) {
    self.store = store
    self.isAUv3 = isAUv3
  }

  public var body: some View {
    GeometryReader { geometryProxy in
      if geometryProxy.size.width <= maxCompactBarWidth {
        HStack(alignment: .center, spacing: controlSpacing) {
          AddSoundFontButton(store: store)
          TagsButton(store: store)
          if isApp {
            EffectsButton(store: store)
          }
          Status(store: store)
          if !store.showMoreButtons {
            Group {
              if showActiveVoiceCount || showMIDITrafficIndicator {
                VoiceCountAndMIDITrafficIndicator(store: store)
              }
              HelpButton(store: store)
            }
          } else {
            Group {
              if isApp {
                HStack(alignment: .center, spacing: keyboardControlSpacing) {
                  ShiftDownButton(store: store)
                    .frame(width: keyboardShiftButtonWidth)
                  SlidingKeyboardButton(store: store)
                  ShiftUpButton(store: store)
                    .frame(width: keyboardShiftButtonWidth)
                }
              }
              EditVisibilityButton(store: store)
              SettingsButton(store: store)
            }
          }
          MoreButton(store: store)
        }
        .animation(.smooth, value: store.lowestKey)
        .animation(.smooth, value: store.highestKey)
        .padding([.horizontal], controlSpacing)
        .padding(0)
        .task {
          await store.send(.initialize(true)).finish()
        }
      } else {
        HStack(alignment: .center, spacing: controlSpacing) {
          AddSoundFontButton(store: store)
          TagsButton(store: store)
          if isApp {
            EffectsButton(store: store)
          }
          Status(store: store)
          if showActiveVoiceCount || showMIDITrafficIndicator {
            VoiceCountAndMIDITrafficIndicator(store: store)
          }
          if isApp {
            HStack(alignment: .center, spacing: keyboardControlSpacing) {
              ShiftDownButton(store: store)
                .frame(width: keyboardShiftButtonWidth)
              SlidingKeyboardButton(store: store)
              ShiftUpButton(store: store)
                .frame(width: keyboardShiftButtonWidth)
            }
          }
          EditVisibilityButton(store: store)
          SettingsButton(store: store)
          HelpButton(store: store)
        }
        .animation(.smooth, value: store.lowestKey)
        .animation(.smooth, value: store.highestKey)
        .padding([.horizontal], controlSpacing)
        .padding(0)
        .task {
          await store.send(.initialize(false)).finish()
        }
      }
    }
    .imageScale(.large)
    .frame(minHeight: height)
    .frame(height: height)
    .padding([.top, .bottom], controlSpacing)
    .background(.windowBackground)
    .animation(.smooth, value: showActiveVoiceCount)
    .animation(.smooth, value: showMIDITrafficIndicator)
    .animation(.smooth, value: store.starFavoriteNames)
    .animation(.smooth, value: store.showMoreButtons)
    .animation(.smooth, value: height)
    .animation(.smooth, value: store.activeVoiceCount)
    .fileImporterFeature(store.scope(state: \.fileImporter, action: \.fileImporter))
  }
}

struct Status: View {
  private var store: StoreOf<ToolBar>
  @Shared(.favoriteSymbolName) private var favoriteSymbolName

  init(store: StoreOf<ToolBar>) {
    self.store = store
  }

  var body: some View {
    HStack {
      if store.showingPresetSymbol {
        Image(systemName: favoriteSymbolName)
          .imageScale(.medium)
      }
      Text(store.statusTextValue)
      Spacer()
    }
    .font(.status)
    .foregroundStyle(store.statusTextColor)
    .animation(.smooth, value: store.statusTextValue)
    .animation(.smooth, value: store.showMoreButtons)
    .contentShape(Rectangle())
    .onTapGesture(count: 2) { store.send(.statusTextTapped(count: 2)) }
    .onTapGesture(count: 1) { store.send(.statusTextTapped(count: 1)) }
    .helpInfoViewTag(.statusWindow)
  }
}

struct VoiceCountAndMIDITrafficIndicator: View {
  private var store: StoreOf<ToolBar>
  @Shared(.showMIDITrafficIndicator) private var showMIDITrafficIndicator
  @Shared(.showActiveVoiceCount) private var showActiveVoiceCount

  init(store: StoreOf<ToolBar>) {
    self.store = store
  }

  var body: some View {
    ZStack(alignment: .center) {
      MIDITrafficIndicatorView(store: store.scope(state: \.midiTrafficIndicator, action: \.midiTrafficIndicator))
        .opacity(showMIDITrafficIndicator ? 1.0 : 0.0)
      Text(store.activeVoiceCount > 0 ? "\(store.activeVoiceCount)" : "")
        .font(.activeVoiceCount)
        .indicator(.activeNoIndicator)
        .opacity(showActiveVoiceCount ? 1.0 : 0.0)
        .contentTransition(.interpolate)
        .transition(.slide)
    }
    .frame(width: 16, alignment: .center)
  }
}

private struct AddSoundFontButton: View {
  var store: StoreOf<ToolBar>

  var body: some View {
    Button {
      store.send(.addSoundFontButtonTapped)
    } label: {
      Image(systemName: .addSoundFontButtonImageName)
        .tint(.mainAccentColor)
    }
    .helpInfoViewTag(RootHelpInfo.addButton)
  }
}

private struct EditVisibilityButton: View {
  var store: StoreOf<ToolBar>

  var body: some View {
    Button {
      store.send(.presetsVisibilityButtonTapped)
    } label: {
      Image(systemName: .presetsVisibilityButtonImageName)
        .tint(if: store.editingPresetVisibility)
    }
    .helpInfoViewTag(.editVisibilityButton)
  }
}

private struct EffectsButton: View {
  var store: StoreOf<ToolBar>

  var body: some View {
    Button {
      store.send(.effectsVisibilityButtonTapped)
    } label: {
      Image(systemName: .effectsButtonImageName)
        .tint(if: store.effectsPanelVisible)
    }
    .helpInfoViewTag(.effectsButton)
  }
}

private struct HelpButton: View {
  var store: StoreOf<ToolBar>

  var body: some View {
    Button {
      store.send(.helpInfoButtonTapped)
    } label: {
      Image(systemName: .helpButtonImageName)
        .tint(Color.mainAccentColor)
    }
  }
}

private struct MoreButton: View {
  var store: StoreOf<ToolBar>

  var body: some View {
    Button {
      store.send(.showMoreButtonTapped)
    } label: {
      Image(systemName: .moreButtonImageName)
        .tint(if: store.showMoreButtons)
    }
    .helpInfoViewTag(.moreButton)
  }
}

private struct SettingsButton: View {
  var store: StoreOf<ToolBar>

  var body: some View {
    Button {
      store.send(.settingsButtonTapped)
    } label: {
      Image(systemName: .settingsButtonImageName)
        .tint(.mainAccentColor)
    }
    .helpInfoViewTag(.settingsButton)
  }
}

private struct ShiftDownButton: View {
  var store: StoreOf<ToolBar>

  var body: some View {
    Button {
      store.send(.shiftKeyboardDownButtonTapped)
    } label: {
      Text(.shiftKeyboardLeftIndicator + store.lowestKey.label)
        .tint(.mainAccentColor)
        .font(.infoBarNoteLabel)
    }
    .disabled(self.store.lowestKey.midiNoteValue == Note.midiRange.lowerBound)
    .helpInfoViewTag(.shiftDownButton)
  }
}

private struct ShiftUpButton: View {
  var store: StoreOf<ToolBar>

  var body: some View {
    Button {
      store.send(.shiftKeyboardUpButtonTapped)
    } label: {
      Text(store.highestKey.label + .shiftKeyboardRightIndicator)
        .tint(.mainAccentColor)
        .font(.infoBarNoteLabel)
    }
    .disabled(self.store.highestKey.midiNoteValue == Note.midiRange.upperBound)
    .helpInfoViewTag(.shiftUpButton)
  }
}

private struct SlidingKeyboardButton: View {
  var store: StoreOf<ToolBar>

  var body: some View {
    Button {
      store.send(.slidingKeyboardButtonTapped)
    } label: {
      Image(systemName: .slidingKeyboardButtonImageName)
        .tint(if: store.keyboardSlides)
    }
    .controlSize(.small)
    .helpInfoViewTag(.slideToggle)
  }
}

private struct TagsButton: View {
  var store: StoreOf<ToolBar>

  var body: some View {
    Button {
      store.send(.tagsListVisibilityButtonTapped)
    } label: {
      Image(systemName: .tagsListButtonImageName)
        .tint(if: store.tagsListVisible)
    }
    .helpInfoViewTag(.tagsButton)
  }
}

private struct AnimationState {
  var angle: Angle = .zero
}

#if DEBUG

extension ToolBarView {
  static func preview() -> some View {

    struct Preview: View {
      let store = Store(
        initialState: .init(
          displayName: "Foo",
          isFavorite: false
        )
      ) {
        ToolBar()
      }

      var body: some View {
        VStack(spacing: 0) {
          ToolBarView(store: store, isAUv3: false)
          KeyboardView(store: Store(initialState: .init()) { Keyboard() })
        }
        .task {
          await store.send(.clearTemporaryStatus).finish()
        }
      }
    }

    return Preview()
  }
}

#Preview {
  ToolBarView.preview()
}

#endif // DEBUG
