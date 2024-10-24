import ComposableArchitecture
import Foundation
import Tagged

public struct ActiveState: Codable, Equatable, Sendable {

  public private(set) var activeSoundFontKey: SoundFontModel.Key?
  public private(set) var selectedSoundFontKey: SoundFontModel.Key?
  public private(set) var activePresetKey: PresetModel.Key?
  public private(set) var activeTagKey: TagModel.Key?

  public init() {}

  public mutating func setActiveSoundFontKey(_ key: SoundFontModel.Key?) {
    activeSoundFontKey = key
  }

  public mutating func setSelectedSoundFontKey(_ key: SoundFontModel.Key?) {
    selectedSoundFontKey = key
  }

  public mutating func setActivePresetKey(_ key: PresetModel.Key) {
    activePresetKey = key
  }

  public mutating func setActiveTagKey(_ key: TagModel.Key) {
    activeTagKey = key
  }
}

extension PersistenceReaderKey where Self == InMemoryKey<ActiveState> {
  public static var activeState: Self {
    inMemory("activeState")
  }
}

public struct CustomAppStorageKey<Value: Sendable, Stored: Sendable> : Sendable {
  private let wrapped: AppStorageKey<Stored>
  private let encoder: @Sendable (Value) -> Stored
  private let decoder: @Sendable (Stored) -> Value

  public init(
    _ wrapped: AppStorageKey<Stored>,
    encoder: @escaping @Sendable (Value)-> Stored,
    decoder: @escaping @Sendable (Stored) -> Value
  ) {
    self.wrapped = wrapped
    self.encoder = encoder
    self.decoder = decoder
  }
}

extension CustomAppStorageKey : PersistenceKey {
  public var id: AnyHashable { wrapped.id }

  public func load(initialValue: Value?) -> Value? {
    wrapped.load(initialValue: initialValue.flatMap(encoder)).flatMap(decoder)
  }

  public func save(_ value: Value) {
    wrapped.save(encoder(value))
  }

  public func subscribe(
    initialValue: Value?,
    didSet: @escaping @Sendable (_ newValue: Value?) -> Void
  ) -> Shared<Value>.Subscription {
    let subscription = wrapped.subscribe(initialValue: initialValue.flatMap(encoder)) { newValue in
      didSet(newValue.flatMap(decoder))
    }
    return Shared<Value>.Subscription {
      subscription.cancel()
    }
  }
}

public struct CodableAppStorageKey<Value: Sendable & Codable> : Sendable {
  private let wrapped: AppStorageKey<Data>

  public init(_ wrapped: AppStorageKey<Data>) {
    self.wrapped = wrapped
  }
}

extension CodableAppStorageKey : PersistenceKey {
  public var id: AnyHashable { wrapped.id }

  public func load(initialValue: Value?) -> Value? {
    wrapped.load(initialValue: initialValue.flatMap(Self.encoder)).flatMap(Self.decoder)
  }

  public func save(_ value: Value) {
    wrapped.save(Self.encoder(value))
  }

  public func subscribe(
    initialValue: Value?,
    didSet: @escaping @Sendable (_ newValue: Value?) -> Void
  ) -> Shared<Value>.Subscription {
    let subscription = wrapped.subscribe(initialValue: initialValue.flatMap(Self.encoder)) { newValue in
      didSet(newValue.flatMap(Self.decoder))
    }
    return Shared<Value>.Subscription {
      subscription.cancel()
    }
  }
}

extension CodableAppStorageKey {

  private static func encoder(_ value: Value) -> Data {
    (try? JSONEncoder().encode(value)) ?? Data()
  }

  private static func decoder(_ value: Data) -> Value? {
    try? JSONDecoder().decode(Value.self, from: value)
  }
}
