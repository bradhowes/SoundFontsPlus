// Copyright © 2025 Brad Howes. All rights reserved.

public import CasePaths
public import ComposableArchitecture
import FeatureSupport
public import SwiftUI

#if os(iOS)

@Reducer
public struct Tutorial {

  public enum Page: Int, CaseIterable {
    case intro = 1
    case fonts
    case presets
    case favorites
    case tags
    case toolBar1
    case toolBar2
    case reverb
    case delay
    case settings
    case last

    var prev: Page { .init(rawValue: self.rawValue - 1) ?? .intro }
    var next: Page { .init(rawValue: self.rawValue + 1) ?? .last }
  }

  @ObservableState
  public struct State: Equatable {
    public var page: Page

    public init(page: Page = .intro) {
      self.page = page
    }
  }

  public enum Action: BindableAction {
    case binding(BindingAction<State>)
    case dismissButtonTapped
    case next
    case page(Page)
    case prev
  }

  public static var shouldShow: Bool {
    @Shared(.showedTutorial) var showedTutorial
    return !showedTutorial
  }

  public init() {}

  @Dependency(\.dismiss) var dismiss

  public var body: some ReducerOf<Self> {
    BindingReducer()

    Reduce { state, action in
      switch action {

      case .binding:
        return .none

      case .dismissButtonTapped:
        return .run { [dismiss] _ in await dismiss() }

      case .next:
        state.page = state.page.next
        return .none

      case .page(let value):
        state.page = value
        return .none

      case .prev:
        state.page = state.page.prev
        return .none
      }
    }
  }
}

public struct TutorialView: View {
  @Bindable private var store: StoreOf<Tutorial>
  private let bottomSpacerMinLength: CGFloat = 24.0
  private let sideTapRegionWidth: CGFloat = 24.0
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  public init(store: StoreOf<Tutorial>) {
    self.store = store
  }

  public var body: some View {
    ZStack(alignment: .top) {
      TabView(selection: $store.page) {
        ForEach(Tutorial.Page.allCases, id: \.self) { page in
          Tab(value: page) {
            ScrollView {
              switch page {
              case .intro: intro
              case .fonts: fonts
              case .presets: presets
              case .favorites: favorites
              case .tags: tags
              case .toolBar1: toolBar1
              case .toolBar2: toolBar2
              case .reverb: reverb
              case .delay: delay
              case .settings: settings
              case .last: last
              }
            }
          }
        }
      }
      .tabViewStyle(.page)
      .indexViewStyle(.page(backgroundDisplayMode: .always))
      .animation(.easeInOut(duration: 1.0), value: store.page)
      .transition(.slide)
      .padding([.leading, .trailing], 16)
      HStack {
        Rectangle()
          .fill(.clear)
          .frame(width: sideTapRegionWidth)
          .frame(maxHeight: .infinity)
          .contentShape(Rectangle())
          .onTapGesture {
            store.send(.prev)
          }
        Spacer()
        Rectangle()
          .fill(.clear)
          .frame(width: sideTapRegionWidth)
          .frame(maxHeight: .infinity)
          .contentShape(Rectangle())
          .onTapGesture {
            store.send(.next)
          }
      }
    }
    .toolbar {
      ToolbarItem(placement: .automatic) {
        Button {
          store.send(.dismissButtonTapped, animation: .default)
        } label: {
          Image(systemName: .checkmarkImageName)
        }
      }
    }
  }
}

struct Page<Content: View>: View {
  private let title: LocalizedStringKey
  private let gist: LocalizedStringKey
  private let rest: () -> Content
  private let bottomSpacerMinLength: CGFloat = 24.0

  init(title: LocalizedStringKey, gist: LocalizedStringKey, @ViewBuilder rest: @escaping () -> Content) {
    self.title = title
    self.gist = gist
    self.rest = rest
  }

  var body: some View {
    VStack(spacing: 18) {
      Text(title)
        .font(.tutorialTitle)
        .foregroundStyle(Color.alternateAccentColor)
      Text(gist)
        .font(.tutorialGist)
      rest()
      Spacer(minLength: bottomSpacerMinLength)
    }
    .font(.tutorialBody)
    .foregroundStyle(.teal)
  }
}

extension TutorialView {

  private var intro: some View {
    Page(
      title: "Welcome to SoundFonts+",
      gist:
"""
This brief tutorial will introduce you to the various parts of the app.

The tutorial will not appear upon future launches of the app, but you can always view it again via the \
\(Image(systemName: .settingsButtonImageName)) Settings panel.
"""
    ) {
      Text("Swipe left or tap along the right edge of the screen to continue.")
        .italic(true)
    }
  }

  private var fonts: some View {
    Page(
      title: "Fonts",
      gist:
"""
The panel on the left-hand side shows names of the installed soundfont files.
"""
    ) {
      HStack(alignment: .top, spacing: 16) {
        Image("FontsList", bundle: Bundle.module)
          .resizable()
          .scaledToFit()
          .frame(width: 140)
          .shadow(
            color: .black,
            radius: CGFloat(6.0),
            x: CGFloat(0), y: CGFloat(0))

        VStack(alignment: .leading, spacing: 24) {
          Grid(verticalSpacing: 12) {
            GridRow {
              Text("•")
              Text("Tap to activate and view the presets")
                .gridColumnAlignment(.leading)
            }
            GridRow {
              Text("•")
              Text("Long-tap to show editor panel")
                .gridColumnAlignment(.leading)
            }
            Text("Swipe Actions")
              .foregroundStyle(Color.alternateAccentColor)
            GridRow {
              Image(systemName: .editButtonImageName)
              Text("Edit name and tags")
                .gridColumnAlignment(.leading)
            }
            GridRow {
              Image(systemName: .deleteButtonImageName)
                .foregroundStyle(.red)
              Text("Remove from device")
                .gridColumnAlignment(.leading)
            }
          }
        }
      }
      Text(
      """
Tap the \(Image(systemName: .addSoundFontButtonImageName)) toolbar button \
to add new files from iCloud or an external disk.
"""
      )
    }
  }

  private var presets: some View {
    Page(
      title: "Presets",
      gist:
"""
The list to the right of the fonts list shows the visible presets in the selected font file.
"""
    ) {
      @Shared(.favoriteSymbolName) var symbolName
      HStack(alignment: .top, spacing: 16) {
        Image("PresetsList", bundle: Bundle.module)
          .resizable()
          .scaledToFit()
          .frame(width: 220)
          .shadow(
            color: .black,
            radius: CGFloat(6.0),
            x: CGFloat(0), y: CGFloat(0))
        VStack(alignment: .leading, spacing: 24) {
          Grid(verticalSpacing: 12) {
            GridRow {
              Text("•")
              Text("Tap to activate")
                .gridColumnAlignment(.leading)
            }
            GridRow {
              Text("•")
              Text("Long-tap to edit")
                .gridColumnAlignment(.leading)
            }
          }
        }
      }
      Text("Swipe Actions")
        .foregroundStyle(Color.alternateAccentColor)
      HStack(spacing: 18) {
        Grid {
          GridRow {
            Image(systemName: .editButtonImageName)
            Text("Edit preset")
              .gridColumnAlignment(.leading)
          }
          GridRow {
            Image(systemName: .favoriteButtonImageName)
              .foregroundStyle(Color.alternateAccentColor)
            Text("Create favorite")
              .gridColumnAlignment(.leading)
          }
        }
        Grid {
          GridRow {
            Image(systemName: .hidePresetButtonImageName)
              .foregroundStyle(.gray)
            Text("Hide preset")
              .gridColumnAlignment(.leading)
          }
          GridRow {
            Image(systemName: .deleteButtonImageName)
              .foregroundStyle(.red)
            Text("Remove favorite")
          }
        }
      }
      Text(
"""
Favorites you create will appear in gold and are prefixed with a \(Image(systemName: symbolName)) \
symbol (configurable). Next page talks more about them.
"""
      )
    }
  }

  private var favorites: some View {
    Page(
      title: "Favorites",
      gist:
"""
Preset copies are known as \"favorites\". \
They provide a way to customize them without needing to edit the font file. They can be highlighted and arranged \
to be easily found in the presets list.
"""
    ) {
      VStack(spacing: 18) {
        Image("PresetsList", bundle: Bundle.module)
          .resizable()
          .scaledToFit()
          .frame(width: 220)
          .shadow(
            color: .black,
            radius: CGFloat(6.0),
            x: CGFloat(0), y: CGFloat(0))
        Text(
"""
A preset can have multiple copies, each with their own name and settings. \
They normally appear below the original preset, but you can change this in the \
\(Image(systemName: .settingsButtonImageName)) Settings panel.
"""
        )
      }
    }
  }

  private var tags: some View {
    Page(
      title: "Tags",
      gist:
"""
Tags help organize your font collection as it grows, allowing you to quickly change which fonts are visible.
"""
    ) {
      HStack(alignment: .top) {
        Image("TagsList", bundle: Bundle.module)
          .resizable()
          .scaledToFit()
          .frame(width: 160)
          .shadow(
            color: .black,
            radius: CGFloat(6.0),
            x: CGFloat(0), y: CGFloat(0))
        VStack(alignment: .leading, spacing: 24) {
          Grid(verticalSpacing: 12) {
            GridRow {
              Text("•")
              Text("Tap to show fonts with tag")
                .gridColumnAlignment(.leading)
            }
            GridRow {
              Text("•")
              Text("Long-tap to edit tags")
                .gridColumnAlignment(.leading)
            }
          }
          Grid(verticalSpacing: 12) {
            Text("Default Tags")
              .foregroundStyle(Color.alternateAccentColor)
            GridRow {
              Text("All")
                .gridColumnAlignment(.trailing)
                .foregroundStyle(.gray)
              Text("Everything")
                .gridColumnAlignment(.leading)
            }
            GridRow {
              Text("Built-in")
                .foregroundStyle(.gray)
              Text("Embedded in app")
            }
            GridRow {
              Text("Added")
                .foregroundStyle(.gray)
              Text("Added by you")
            }
            GridRow {
              Text("External")
                .foregroundStyle(.gray)
              Text("On iCloud or external disk")
            }
          }
          if horizontalSizeClass != .compact {
            Text("Swipe Actions")
              .foregroundStyle(Color.alternateAccentColor)
            Grid {
              GridRow {
                Image(systemName: .editButtonImageName)
                Text("Edit tags")
                  .gridColumnAlignment(.leading)
              }
              GridRow {
                Image(systemName: .deleteButtonImageName)
                  .foregroundStyle(.red)
                Text("Remove user tag")
              }
            }
          }
        }
      }
      Text(
"""
Tap the \(Image(systemName: .tagsListButtonImageName)) button to see the tag panel.
"""
      )
      if horizontalSizeClass == .compact {
        Text("Swipe Actions")
          .foregroundStyle(Color.alternateAccentColor)
        HStack(spacing: 18) {
          Grid {
            GridRow {
              Image(systemName: .editButtonImageName)
              Text("Edit tags")
                .gridColumnAlignment(.leading)
            }
          }
          Grid {
            GridRow {
              Image(systemName: .deleteButtonImageName)
                .foregroundStyle(.red)
              Text("Remove user tag")
            }
          }
        }
      }
    }
  }

  private var toolBar1: some View {
    Page(
      title: "Toolbar",
      gist:
"""
Shows the active preset name, MIDI activity indicator, active voice count, and various conrols for accessing additional \
parts of the application.
"""
    ) {
      Image("ToolBar1", bundle: Bundle.module)
        .resizable()
        .scaledToFit()
        .shadow(
          color: .black,
          radius: CGFloat(6.0),
          x: CGFloat(0), y: CGFloat(0))
      Grid(verticalSpacing: 12) {
        GridRow {
          Image(systemName: .addSoundFontButtonImageName)
            .gridColumnAlignment(.trailing)
          Text("Add a new soundfont file")
            .gridColumnAlignment(.leading)
        }
        GridRow {
          Image(systemName: .tagsListButtonImageName)
            .gridColumnAlignment(.trailing)
          Text("Toggle tag list visibility")
        }
        GridRow {
          Image(systemName: .effectsButtonImageName)
            .gridColumnAlignment(.trailing)
          Text("Toggle effects panel visibility")
        }
        GridRow {
          Image(systemName: .moreButtonImageName)
            .gridColumnAlignment(.trailing)
          Text("Show more controls (in narrow views)")
        }
        GridRow {
          Image(systemName: .tapImageName)
            .gridColumnAlignment(.trailing)
          Text("Single-tap on the preset name to scroll to its entry.")
        }
        GridRow {
          HStack {
            Image(systemName: .tapImageName)
            Image(systemName: .tapImageName)
          }
          .gridColumnAlignment(.trailing)
          Text("Double-tap on the preset name to cancel all active notes in the synth (aka PANIC).")
        }
      }
    }
  }

  private var toolBar2: some View {
    Page(
      title: "More Controls",
      gist:
"""
Change the visible key range with the \(.shiftKeyboardLeftIndicator) and \(.shiftKeyboardRightIndicator) buttons. \
You can have a preset/favorite adjust the keyboard when it becomes active. \
Tap \(Image(systemName: .fixedKeyboardButtonImageName)) to toggle keyboard sliding during playing.
"""
    ) {
      Image("ToolBar2", bundle: Bundle.module)
        .shadow(
          color: .black,
          radius: CGFloat(6.0),
          x: CGFloat(0), y: CGFloat(0))
      Grid(verticalSpacing: 12) {
        GridRow {
          Image(systemName: .settingsButtonImageName)
          Text("Show application settings panel")
            .gridColumnAlignment(.leading)
        }
        GridRow {
          Image(systemName: .presetsVisibilityButtonImageName)
          Text("Change visibility of presets")
        }
        GridRow {
          Image(systemName: .helpButtonImageName)
          Text("Show quick-help guide")
        }
        GridRow {
          Image(systemName: .moreButtonImageName)
            .foregroundStyle(Color.alternateAccentColor)
          Text("Hide these buttons (in narrow views)")
        }
      }
    }
  }

  private var reverb: some View {
    Page(
      title: "Reverb Controls",
      gist:
"""
You can add a reverberation effect to a preset and save its configuration so that it is restored when the preset activates. \
Tap the \(Image(systemName: .effectsButtonImageName)) toolbar button to show. \
Swipe up/down to change room or adjust knob value.
"""
    ) {
      Image("Reverb", bundle: Bundle.module)
        .resizable()
        .scaledToFit()
        .frame(width: 340)
        .shadow(
          color: .black,
          radius: CGFloat(6.0),
          x: CGFloat(0), y: CGFloat(0))
      Text("Controls")
        .foregroundStyle(Color.alternateAccentColor)
      Grid(verticalSpacing: 12) {
        GridRow {
          HStack {
            Image(systemName: .arrowDownButtonImageName)
            Text("On")
          }
          .gridColumnAlignment(.trailing)
          .foregroundStyle(.gray)
          Text("Toggle reverb effect")
            .gridColumnAlignment(.leading)
        }
        GridRow {
          HStack {
            Image(systemName: .arrowDownButtonImageName)
            Text("\(Image(systemName: .effectsLockButtonImageName))")
          }
          .foregroundStyle(.gray)
          Text("Keep settings when preset changes")
        }
        GridRow {
          Text("Room")
            .foregroundStyle(.gray)
          Text("Reverberation settings for different room types")
        }
        GridRow {
          Text("Amount")
            .foregroundStyle(.gray)
          Text("Level of the source audio vs. reverberated")
        }
      }
    }
  }

  private var delay: some View {
    Page(
      title: "Delay Controls",
      gist:
"""
You can also add a delay effect to a preset's audio output. Swipe up/down on knob or \
tap on label to enter numeric value.
"""
    ) {
      Image("Delay", bundle: Bundle.module)
        .resizable()
        .scaledToFit()
        .frame(width: 340)
        .shadow(
          color: .black,
          radius: CGFloat(6.0),
          x: CGFloat(0), y: CGFloat(0))
      Text("Controls")
        .foregroundStyle(Color.alternateAccentColor)
      Grid(verticalSpacing: 12) {
        GridRow {
          HStack {
            Image(systemName: .arrowDownButtonImageName)
            Text("On")
          }
          .gridColumnAlignment(.trailing)
          .foregroundStyle(.gray)
          Text("Toggle reverb effect")
            .gridColumnAlignment(.leading)
        }
        GridRow {
          HStack {
            Image(systemName: .arrowDownButtonImageName)
            Text("\(Image(systemName: .effectsLockButtonImageName))")
          }
          .foregroundStyle(.gray)
          Text("Keep settings when preset changes")
        }
        GridRow {
          Text("Time")
            .foregroundStyle(.gray)
          Text("Delay before replaying source audio")
        }
        GridRow {
          Text("Feedback")
            .foregroundStyle(.gray)
          Text("Level and phase of repeated audio")
        }
        GridRow {
          Text("Cutoff")
            .foregroundStyle(.gray)
          Text("Low-pass filter applied to delayed audio")
        }
        GridRow {
          Text("Amount")
            .foregroundStyle(.gray)
          Text("Level of the source audio vs. delayed")
        }
      }
    }
  }

  private var settings: some View {
    Page(
      title: "Finally…",
      gist: "Here are some additional features available to you:"
    ) {
      Grid(alignment: .leadingFirstTextBaseline, verticalSpacing: 12) {
        GridRow {
          Text("•")
            .foregroundStyle(Color.alternateAccentColor)
          Text("Use as AUv3 components in supported audio apps like GarageBand and Cubasis")
            .gridColumnAlignment(.leading)
        }
        GridRow {
          Text("•")
            .foregroundStyle(Color.alternateAccentColor)
          Text("Use MIDI controllers to play notes and adjust settings")
            .gridColumnAlignment(.leading)
        }
        GridRow {
          Text("•")
            .foregroundStyle(Color.alternateAccentColor)
          Text("Connect using Bluetooth MIDI")
            .gridColumnAlignment(.leading)
        }
        GridRow {
          Text("•")
            .foregroundStyle(Color.alternateAccentColor)
          Text("Adjust the width of the virtual keyboard keys")
            .gridColumnAlignment(.leading)
        }
        GridRow {
          Text("•")
            .foregroundStyle(Color.alternateAccentColor)
          Text("Show solfège labels")
            .gridColumnAlignment(.leading)
        }
        GridRow {
          Text("•")
            .foregroundStyle(Color.alternateAccentColor)
          Text(
"""
Transpose pitch or set A4 frequency to values other than 440 Hz, either for a specific preset \
or globally.
"""
          )
            .gridColumnAlignment(.leading)
        }
      }
      .font(.body)
      Grid {
        GridRow {
          Image(systemName: .settingsButtonImageName)
            .imageScale(.large)
          Text("Tap to access these settings and more")
            .font(.body)
        }
      }
    }
    .foregroundStyle(.teal)
  }

  private var last: some View {
    VStack(spacing: 18) {
      Text("Enjoy!")
        .font(.largeTitle)
        .foregroundStyle(Color.alternateAccentColor)
      Button {
        store.send(.dismissButtonTapped)
      } label: {
        Text("Begin making music")
          .foregroundStyle(.teal)
      }
    }
  }
}

extension View {

  public func tutorialSheet(_ store: Binding<StoreOf<Tutorial>?>) -> some View {
    self
      .sheet(item: store) { child in
        NavigationStack {
          TutorialView(store: child)
        }
      }
  }
}

#if DEBUG

#Preview {
  @Previewable @State var showTutorial: Bool = false
  VStack {
    Text("This is a test")
    Button {
      showTutorial = true
    } label: {
      Text("Show tutorial")
    }
  }
  .sheet(isPresented: $showTutorial) {
    NavigationStack {
      TutorialView(store: Store(initialState: .init(page: .intro)) { Tutorial() })
    }
  }
}

#endif // DEBUG

#endif // os(iOS)
