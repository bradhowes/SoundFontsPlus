import Sharing

extension String {
  public static let dropEffectsView = "dropEffectsView"
  public static let effectsVisible = "effectsVisible"
  public static let fontsAndPresetsSplitFraction = "fontsAndPresetsSplitFraction"
  public static let fontsAndTagsSplitFraction = "fontsAndTagsSplitFraction"
  public static let tagsListVisible = "tagsListVisible"
}

extension SharedKey where Self == InMemoryKey<Bool>.Default {

  public static var dropEffectsView: Self {
    Self[.inMemory(.dropEffectsView), default: true]
  }

  public static var effectsVisible: Self {
    Self[.inMemory(.effectsVisible), default: false]
  }

  public static var tagsListVisible: Self {
    Self[.inMemory(.tagsListVisible), default: false]
  }
}
