// Copyright © 2025 Brad Howes. All rights reserved.

import FeatureSupport
import Keyboard
import MIDITrafficIndicator
import SwiftUI

public struct ToolBarView: View {
  private var store: StoreOf<ToolBar>
  @Shared(.showActiveVoiceCount) private var showActiveVoiceCount
  @Shared(.showMIDITrafficIndicator) private var showMIDITrafficIndicator
  @Shared(.favoriteSymbolName) private var favoriteSymbolName
  @Shared(.starFavoriteNames) private var starFavoriteNames
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @Environment(\.colorScheme) private var colorScheme

  private let isAUv3: Bool
  private var isApp: Bool { !isAUv3 }

  private var showingPresetSymbol: Bool { starFavoriteNames && store.preset?.kind == .favorite && store.temporaryStatus == nil }
  private var statusTextValue: String { store.temporaryStatus?.text ?? store.preset?.displayName ?? "—" }
  private var statusTextColor: Color {
    (store.preset?.kind == .favorite || store.temporaryStatus != nil) ? .alternateAccentColor : .mainAccentColor
  }

  private var height: CGFloat { store.showMoreButtons ? 82 : 40 }

  public init(store: StoreOf<ToolBar>, isAUv3: Bool) {
    self.store = store
    self.isAUv3 = isAUv3
  }

  public var body: some View {
    Group {
      if horizontalSizeClass == .compact {
        compactBar
      } else {
        fullBar
      }
    }
    .imageScale(.large)
    .padding([.leading, .trailing], 8)
    .background(.windowBackground)
    .frame(height: height)
    .frame(maxHeight: height)
    .animation(.smooth, value: store.showMoreButtons)
    .animation(.smooth, value: store.activeVoiceCount)
    .fileImporterFeature(store.scope(state: \.fileImporter, action: \.fileImporter))
    .task {
      await store.send(.initialize(horizontalSizeClass == .compact)).finish()
    }
  }
}

extension ToolBarView {

  private var fullBar: some View {
    HStack(alignment: .center, spacing: 12) {
      if isApp {
        fullBarApp
      } else {
        fullBarAUv3
      }
    }
  }

  @ViewBuilder
  private var fullBarApp: some View {
    addSoundFontButton
    tagsButton
    effectsButton
    status
    shiftDownButton
    slidingKeyboardButton
    shiftUpButton
    editVisibilityButton
    settingsButton
    helpButton
  }

  @ViewBuilder
  private var fullBarAUv3: some View {
    tagsButton
    status
    editVisibilityButton
    settingsButton
    helpButton
  }

  private var compactBar: some View {
    VStack(alignment: .center, spacing: 0) {
      HStack(alignment: .center, spacing: 12) {
        if isApp {
          compactBarApp
        } else {
          compactBarAUv3
        }
      }
      Color.splitViewHandleBackgroundColor
        .frame(height: store.showMoreButtons ? 2 : 0)
        .frame(maxHeight: store.showMoreButtons ? 2 : 0)
        .clipped()
      HStack(alignment: .center, spacing: 12) {
        Spacer()
        shiftDownButton
        slidingKeyboardButton
        shiftUpButton
        Spacer()
        editVisibilityButton
        settingsButton
        helpButton
      }
      .frame(height: store.showMoreButtons ? 40 : 0)
      .frame(maxHeight: store.showMoreButtons ? 40 : 0)
      .clipped()
    }
  }

  @ViewBuilder
  private var compactBarApp: some View {
    addSoundFontButton
    tagsButton
    effectsButton
    status
    moreButton
  }

  @ViewBuilder
  private var compactBarAUv3: some View {
    tagsButton
    if store.showMoreButtons {
      Spacer()
        .frame(height: 40)
        .background(.windowBackground)
      editVisibilityButton
      settingsButton
    } else {
      status
    }
    moreButton
  }

  private var status: some View {
    ZStack(alignment: .leading) {
      if showMIDITrafficIndicator {
        MIDITrafficIndicatorView(store: store.scope(state: \.midiTrafficIndicator, action: \.midiTrafficIndicator))
          .zIndex(-99)
      }
      HStack {
        if showActiveVoiceCount || showMIDITrafficIndicator {
          voiceCountAndTrafficIndicator
            .transition(.slide)
        }
        statusText
      }
      .animation(.smooth, value: showActiveVoiceCount || showMIDITrafficIndicator)
    }
    .helpInfoViewTag(.statusWindow)
  }

  private var voiceCountAndTrafficIndicator: some View {
    Text(store.activeVoiceCount > 0 ? "\(store.activeVoiceCount)" : "")
      .font(.activeVoiceCount)
      .indicator(.activeNoIndicator)
      .contentTransition(.interpolate)
      .frame(width: 24, alignment: .center)
  }

  private var statusText: some View {
    HStack {
      if showingPresetSymbol {
        Image(systemName: favoriteSymbolName)
      }
      Text(statusTextValue)
      Spacer()
    }
    .font(.status)
    .foregroundStyle(statusTextColor)
    .contentTransition(.interpolate)
    .animation(.smooth, value: statusTextValue)
    .contentShape(Rectangle())
    .onTapGesture(count: 2) { store.send(.statusTextTapped(count: 2)) }
    .onTapGesture(count: 1) { store.send(.statusTextTapped(count: 1)) }
  }

  private var addSoundFontButton: some View {
    Button {
      store.send(.addSoundFontButtonTapped)
    } label: {
      Image(systemName: .addSoundFontButtonImageName)
        .tint(.mainAccentColor)
    }
    .helpInfoViewTag(RootHelpInfo.addButton)
  }

  private var editVisibilityButton: some View {
    Button {
      store.send(.presetsVisibilityButtonTapped)
    } label: {
      Image(systemName: .presetsVisibilityButtonImageName)
        .tint(if: store.editingPresetVisibility)
    }
    .helpInfoViewTag(.editVisibilityButton)
  }

  private var effectsButton: some View {
    print("effectsButton - \(store.effectsPanelVisible)")
    return Button {
      store.send(.effectsVisibilityButtonTapped)
    } label: {
      Image(systemName: .effectsButtonImageName)
        .tint(if: store.effectsPanelVisible)
    }
    .helpInfoViewTag(.effectsButton)
  }

  private var helpButton: some View {
    Button {
      store.send(.helpButtonTapped)
    } label: {
      Image(systemName: .helpButtonImageName)
        .tint(Color.mainAccentColor)
    }
  }

  private var moreButton: some View {
    Button {
      store.send(.showMoreButtonTapped)
    } label: {
      Image(systemName: store.showMoreButtons ? .lessButtonImageName : .moreButtonImageName)
        .tint(if: store.showMoreButtons)
        .frame(width: 24)
    }
    .contentTransition(.symbolEffect(.replace))
    .helpInfoViewTag(.moreButton)
  }

  private var settingsButton: some View {
    Button {
      store.send(.settingsButtonTapped)
    } label: {
      Image(systemName: .settingsButtonImageName)
        .tint(.mainAccentColor)
    }
    .helpInfoViewTag(.settingsButton)
  }

  private var shiftDownButton: some View {
    Button {
      store.send(.shiftKeyboardDownButtonTapped)
    } label: {
      Text(.shiftKeyboardLeftIndicator + store.lowestKey.label)
        .frame(width: 40, alignment: .trailing)
        .tint(.mainAccentColor)
    }
    .disabled(self.store.lowestKey.midiNoteValue == Note.midiRange.lowerBound)
    .helpInfoViewTag(.shiftDownButton)
  }

  private var shiftUpButton: some View {
    Button {
      store.send(.shiftKeyboardUpButtonTapped)
    } label: {
      Text(store.highestKey.label + .shiftKeyboardRightIndicator)
        .frame(width: 40, alignment: .leading)
        .tint(.mainAccentColor)
    }
    .disabled(self.store.highestKey.midiNoteValue == Note.midiRange.upperBound)
    .helpInfoViewTag(.shiftUpButton)
  }

  private var slidingKeyboardButton: some View {
    Button {
      store.send(.slidingKeyboardButtonTapped)
    } label: {
      Image(
        systemName: store.keyboardSlides
        ? .slidingKeyboardButtonImageName
        : .fixedKeyboardButtonImageName
      )
      .fixedSize()
      .tint(if: store.keyboardSlides)
    }
    .helpInfoViewTag(.slideToggle)
  }

 private var tagsButton: some View {
    Button {
      store.send(.tagsListVisibilityButtonTapped)
    } label: {
      Image(systemName: .tagsListButtonImageName)
        .tint(if: store.tagsListVisible)
    }
    .helpInfoViewTag(.tagsButton)
  }
}

#if DEBUG

extension ToolBarView {
  static func preview() -> some View {
    struct Preview: View {
      @Shared(.showActiveVoiceCount) var showActiveVoiceCount
      @Shared(.showMIDITrafficIndicator) var showMIDITrafficIndicator

      var body: some View {
        VStack {
          Toggle(
            "Show active voice count",
            isOn: Binding(
              get: { showActiveVoiceCount },
              set: { newValue in $showActiveVoiceCount.withLock { $0 = newValue }}
            )
          )
          .circledCheckMarkToggleStyle()
          Toggle(
              "Show MIDI traffic indicator",
              isOn: Binding(
                get: { showMIDITrafficIndicator },
                set: { newValue in $showMIDITrafficIndicator.withLock { $0 = newValue }}
              )
          )
          .circledCheckMarkToggleStyle()
          ToolBarView(
            store: Store(
              initialState: .init(
                preset: Preset(
                  id: 0,
                  index: 0,
                  bank: 1,
                  program: 1,
                  originalName: "Foo",
                  soundFontId: 0,
                  displayName: "Foo"
                )
              )
            ) {
            ToolBar()
          }, isAUv3: false)
          KeyboardView(store: Store(initialState: .init()) { Keyboard() })
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
