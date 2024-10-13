import ComposableArchitecture
import Foundation

extension PersistenceReaderKey where Self == AppStorageKey<String?> {
  /// Setting for the selected font if not the active one
  public static var selectedSoundFont: Self { appStorage("selectedSoundFont") }
  /// Setting for the active font
  public static var activeSoundFont: Self { appStorage("activeSoundFont") }
}

extension PersistenceReaderKey where Self == AppStorageKey<Int> {
  /// Setting for the active preset -- the one that is active in the synth
  public static var activePreset: Self { appStorage("activePreset") }
}

extension PersistenceReaderKey where Self == AppStorageKey<UUID?> {
  /// Setting for the active tag that controls what fonts to show
  public static var activeTag: Self { appStorage("activeTag") }
}

extension PersistenceReaderKey where Self == PersistenceKeyDefault<AppStorageKey<String?>> {
  public static var selectedSoundFont: Self { PersistenceKeyDefault(.selectedSoundFont, nil) }
  public static var activeSoundFont: Self { PersistenceKeyDefault(.activeSoundFont, nil) }
}

extension PersistenceReaderKey where Self == PersistenceKeyDefault<AppStorageKey<Int>> {
  public static var activePreset: Self { PersistenceKeyDefault(.activePreset, 0) }
}

extension PersistenceReaderKey where Self == PersistenceKeyDefault<AppStorageKey<UUID?>> {
  public static var activeTag: Self { PersistenceKeyDefault(.activeTag, nil) }
}

extension UUID: @retroactive RawRepresentable {
  public typealias RawValue = String

  public var rawValue: String { self.uuidString }

  public init?(rawValue: String) {
    if let value = UUID(uuidString: rawValue) {
      self = value
    } else {
      return nil
    }
  }
}
