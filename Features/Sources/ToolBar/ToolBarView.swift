// Copyright © 2025 Brad Howes. All rights reserved.

import FeatureSupport
import Keyboard
import MIDITrafficIndicator
import SwiftUI

public struct ToolBarView: View {
  private var store: StoreOf<ToolBar>
  @Shared(.showActiveVoiceCount) private var showActiveVoiceCount
  @Shared(.showMIDITrafficIndicator) private var showMIDITrafficIndicator
  @Shared(.isAUv3) private var isAUv3
  @Shared(.favoriteSymbolName) private var favoriteSymbolName
  @Shared(.starFavoriteNames) private var starFavoriteNames
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var showingPresetSymbol: Bool { starFavoriteNames && store.preset?.kind == .favorite && store.temporaryStatus == nil }
  private var statusTextValue: String { store.temporaryStatus?.text ?? store.preset?.displayName ?? "—" }
  private var statusTextColor: Color {
    (store.preset?.kind == .favorite || store.temporaryStatus != nil) ? .alternateAccentColor : .mainAccentColor
  }

  public init(store: StoreOf<ToolBar>) {
    self.store = store
  }

  public var body: some View {
    HStack(alignment: .center, spacing: 12) {
      addSoundFontButton
      tagsButton
      effectsButton
      ZStack(alignment: .trailing) {
        status
          .zIndex(0)
          .opacity(store.showMoreButtons ? 0.0 : 1.0)
        additionalButtons
          .opacity((store.showMoreButtons || horizontalSizeClass != .compact) ? 1.0 : 0.0)
          .offset(x: horizontalSizeClass == .compact ? 12 : 0)
          .zIndex(1)
          .transition(.move(edge: .trailing))
        moreButton
          .zIndex(horizontalSizeClass == .compact ? 2 : -99)
          .offset(x: 4)
          // .opacity(horizontalSizeClass == .compact ? 1.0 : 0.0)
      }
    }
    .imageScale(.large)
    .background(Color.black)
    .frame(height: 40)
    .frame(maxHeight: 40)
    .animation(.easeInOut, value: store.showMoreButtons)
    .animation(.smooth, value: store.activeVoiceCount)
    .fileImporterFeature(store.scope(state: \.fileImporter, action: \.fileImporter))
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
  }

  private var tagsButton: some View {
    Button {
      store.send(.tagsListVisibilityButtonTapped)
    } label: {
      Image(systemName: .tagsListButtonImageName)
        .tint(if: store.tagsListVisible)
    }
  }

  private var effectsButton: some View {
    Button {
      store.send(.effectsVisibilityButtonTapped)
    } label: {
      Image(systemName: .effectsButtonImageName)
        .tint(if: store.effectsPanelVisible)
    }
  }

  private var moreButton: some View {
    Button {
      store.send(.showMoreButtonTapped)
    } label: {
      Image(systemName: .moreButtonImageName)
        .tint(if: store.showMoreButtons)
        .frame(width: 24)
    }
  }

  private var additionalButtons: some View {
    HStack(alignment: .center, spacing: 12) {
      Button {
        store.send(.shiftKeyboardDownButtonTapped)
      } label: {
        Text(.shiftKeyboardLeftIndicator + store.lowestKey.label)
          .fixedSize()
          .tint(.mainAccentColor)
      }
      .disabled(self.store.lowestKey.midiNoteValue == Note.midiRange.lowerBound)
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
      Button {
        store.send(.shiftKeyboardUpButtonTapped)
      } label: {
        Text(store.highestKey.label + .shiftKeyboardRightIndicator)
          .fixedSize()
          .tint(.mainAccentColor)
      }
      .disabled(self.store.highestKey.midiNoteValue == Note.midiRange.upperBound)
      Button {
        store.send(.presetsVisibilityButtonTapped)
      } label: {
        Image(systemName: .presetsVisibilityButtonImageName)
          .tint(if: store.editingPresetVisibility)
      }
      Button {
        store.send(.settingsButtonTapped)
      } label: {
        Image(systemName: .settingsButtonImageName)
          .tint(.mainAccentColor)
      }
      Button {
        store.send(.helpButtonTapped)
      } label: {
        Image(systemName: .helpButtonImageName)
          .tint(.mainAccentColor)
      }
    }
  }
}

#if DEBUG

extension ToolBarView {
  static func preview(showMoreButtons: Bool) -> some View {
    struct Preview: View {
      @Shared(.showActiveVoiceCount) var showActiveVoiceCount
      @State var showMoreButtons: Bool

      init(showMoreButtons: Bool) {
        self.showMoreButtons = showMoreButtons
      }

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
          Toggle("Show more buttons", isOn: $showMoreButtons)
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
                ),
                showMoreButtons: showMoreButtons
              )
            ) {
            ToolBar()
          })
          KeyboardView(store: Store(initialState: .init()) { Keyboard() })
        }
      }
    }

    return Preview(showMoreButtons: showMoreButtons)
  }
}

#Preview {
  ToolBarView.preview(showMoreButtons: false)
}

#endif // DEBUG
