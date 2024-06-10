import ComposableArchitecture
import Dependencies
import Extensions
import Foundation


public struct AppGroupStoreSpec<Value>: Sendable where Value: Sendable {
  fileprivate let key: String
  fileprivate let store: UserDefaults

  public init(_ key: String, store: KeyPath<DependencyValues, UserDefaults>) {
    @Dependency(store) var storage
    self.key = key
    self.store = storage
  }

  public static func spec(_ key: String, store: KeyPath<DependencyValues, UserDefaults>) -> Self {
    .init(key, store: store)
  }
}

extension PersistenceReaderKey {

  // MARK: - Bool values

  public static func appGroupStore(_ key: String, store: KeyPath<DependencyValues, UserDefaults>) -> Self
  where Self == AppGroupStoreKey<Bool> {
    AppGroupStoreKey(.init(key, store: store))
  }

  public static func appGroupStore(_ spec: AppGroupStoreSpec<Value>) -> Self where Self == AppGroupStoreKey<Bool> {
    AppGroupStoreKey(spec)
  }

  public static func appGroupStore(_ key: String, store: KeyPath<DependencyValues, UserDefaults>) -> Self
  where Self == AppGroupStoreKey<Bool?> {
    AppGroupStoreKey(.init(key, store: store))
  }

  public static func appGroupStore(_ spec: AppGroupStoreSpec<Value>) -> Self where Self == AppGroupStoreKey<Bool?> {
    AppGroupStoreKey(spec)
  }

  // MARK: - Int values

  public static func appGroupStore(_ key: String, store: KeyPath<DependencyValues, UserDefaults>) -> Self
  where Self == AppGroupStoreKey<Int> {
    AppGroupStoreKey(.init(key, store: store))
  }

  public static func appGroupStore(_ spec: AppGroupStoreSpec<Value>) -> Self where Self == AppGroupStoreKey<Int> {
    AppGroupStoreKey(spec)
  }

  public static func appGroupStore(_ key: String, store: KeyPath<DependencyValues, UserDefaults>) -> Self
  where Self == AppGroupStoreKey<Int?> {
    AppGroupStoreKey(.init(key, store: store))
  }

  public static func appGroupStore(_ spec: AppGroupStoreSpec<Value>) -> Self where Self == AppGroupStoreKey<Int?> {
    AppGroupStoreKey(spec)
  }

  // MARK: - Double values

  public static func appGroupStore(_ key: String, store: KeyPath<DependencyValues, UserDefaults>) -> Self
  where Self == AppGroupStoreKey<Double> {
    AppGroupStoreKey(.init(key, store: store))
  }

  public static func appGroupStore(_ spec: AppGroupStoreSpec<Double>) -> Self where Self == AppGroupStoreKey<Double> {
    AppGroupStoreKey(spec)
  }

  public static func appGroupStore(_ key: String, store: KeyPath<DependencyValues, UserDefaults>) -> Self
  where Self == AppGroupStoreKey<Double?> {
    AppGroupStoreKey(.init(key, store: store))
  }

  public static func appGroupStore(_ spec: AppGroupStoreSpec<Value>) -> Self where Self == AppGroupStoreKey<Double?> {
    AppGroupStoreKey(spec)
  }

  // MARK: - String values

  public static func appGroupStore(_ key: String, store: KeyPath<DependencyValues, UserDefaults>) -> Self
  where Self == AppGroupStoreKey<String> {
    AppGroupStoreKey(.init(key, store: store))
  }

  public static func appGroupStore(_ spec: AppGroupStoreSpec<Value>) -> Self where Self == AppGroupStoreKey<String> {
    AppGroupStoreKey(spec)
  }

  public static func appGroupStore(_ key: String, store: KeyPath<DependencyValues, UserDefaults>) -> Self
  where Self == AppGroupStoreKey<String?> {
    AppGroupStoreKey(.init(key, store: store))
  }

  public static func appGroupStore(_ spec: AppGroupStoreSpec<Value>) -> Self where Self == AppGroupStoreKey<String?> {
    AppGroupStoreKey(spec)
  }

  // MARK: - URL values

  public static func appGroupStore(_ key: String, store: KeyPath<DependencyValues, UserDefaults>) -> Self
  where Self == AppGroupStoreKey<URL> {
    AppGroupStoreKey(.init(key, store: store))
  }

  public static func appGroupStore(_ spec: AppGroupStoreSpec<Value>) -> Self where Self == AppGroupStoreKey<URL> {
    AppGroupStoreKey(spec)
  }

  public static func appGroupStore(_ key: String, store: KeyPath<DependencyValues, UserDefaults>) -> Self
  where Self == AppGroupStoreKey<URL?> {
    AppGroupStoreKey(.init(key, store: store))
  }

  public static func appGroupStore(_ spec: AppGroupStoreSpec<Value>) -> Self where Self == AppGroupStoreKey<URL?> {
    AppGroupStoreKey(spec)
  }

  // MARK: - Data values

  public static func appGroupStore(_ key: String, store: KeyPath<DependencyValues, UserDefaults>) -> Self
  where Self == AppGroupStoreKey<Data> {
    AppGroupStoreKey(.init(key, store: store))
  }

  public static func appGroupStore(_ spec: AppGroupStoreSpec<Value>) -> Self where Self == AppGroupStoreKey<Data> {
    AppGroupStoreKey(spec)
  }

  public static func appGroupStore(_ key: String, store: KeyPath<DependencyValues, UserDefaults>) -> Self
  where Self == AppGroupStoreKey<Data?> {
    AppGroupStoreKey(.init(key, store: store))
  }

  public static func appGroupStore(_ spec: AppGroupStoreSpec<Value>) -> Self where Self == AppGroupStoreKey<Data?> {
    AppGroupStoreKey(spec)
  }

  // MARK: - RawRepresentable/Int values

  public static func appGroupStore<Value: RawRepresentable>(
    _ key: String,
    store: KeyPath<DependencyValues, UserDefaults>
  ) -> Self
  where Value.RawValue == Int, Self == AppGroupStoreKey<Value>, Value: Sendable {
    AppGroupStoreKey(.init(key, store: store))
  }

  public static func appGroupStore<Value: RawRepresentable>(_ spec: AppGroupStoreSpec<Value>) -> Self
  where Value.RawValue == Int, Self == AppGroupStoreKey<Value> {
    AppGroupStoreKey(spec)
  }

  public static func appGroupStore<Value: RawRepresentable>(
    _ key: String,
    store: KeyPath<DependencyValues, UserDefaults>
  ) -> Self
  where Value.RawValue == Int, Self == AppGroupStoreKey<Value?>, Value: Sendable {
    AppGroupStoreKey(.init(key, store: store))
  }

  public static func appGroupStore<Value: RawRepresentable>(_ spec: AppGroupStoreSpec<Value?>) -> Self
  where Value.RawValue == Int, Self == AppGroupStoreKey<Value?> {
    AppGroupStoreKey(spec)
  }

  // MARK: - RawRepresentable/String values

  public static func appGroupStore<Value: RawRepresentable>(
    _ key: String,
    store: KeyPath<DependencyValues, UserDefaults>
  ) -> Self
  where Value.RawValue == String, Self == AppGroupStoreKey<Value>, Value: Sendable {
    AppGroupStoreKey(.init(key, store: store))
  }

  public static func appGroupStore<Value: RawRepresentable>(_ spec: AppGroupStoreSpec<Value>) -> Self
  where Value.RawValue == String, Self == AppGroupStoreKey<Value> {
    AppGroupStoreKey(spec)
  }

  public static func appGroupStore<Value: RawRepresentable>(
    _ key: String,
    store: KeyPath<DependencyValues, UserDefaults>
  ) -> Self
  where Value.RawValue == String, Self == AppGroupStoreKey<Value?>, Value: Sendable {
    AppGroupStoreKey(.init(key, store: store))
  }

  public static func appGroupStore<Value: RawRepresentable>(_ spec: AppGroupStoreSpec<Value?>) -> Self
  where Value.RawValue == String, Self == AppGroupStoreKey<Value?> {
    AppGroupStoreKey(spec)
  }

  // MARK: - Codable values

  public static func appGroupStore<Value: Codable>(
    _ key: String,
    store: KeyPath<DependencyValues, UserDefaults>
  ) -> Self
  where Self == AppGroupStoreKey<Value>, Value: Sendable {
    AppGroupStoreKey(.init(key, store: store))
  }

  public static func appGroupStore<Value: Codable>(_ spec: AppGroupStoreSpec<Value>) -> Self
  where Self == AppGroupStoreKey<Value>, Value: Sendable {
    AppGroupStoreKey(spec)
  }

  public static func appGroupStore<Value: Codable>(
    _ key: String,
    store: KeyPath<DependencyValues, UserDefaults>
  ) -> Self
  where Self == AppGroupStoreKey<Value?>, Value: Sendable {
    AppGroupStoreKey(.init(key, store: store))
  }

  public static func appGroupStore<Value: Codable>(_ spec: AppGroupStoreSpec<Value?>) -> Self
  where Self == AppGroupStoreKey<Value?>, Value: Sendable {
    AppGroupStoreKey(spec)
  }
}

extension UserDefaults: @unchecked Sendable {}

public struct AppGroupStoreKey<Value: Sendable> : Sendable {
  private let shim: any Shim<Value>
  private let spec: AppGroupStoreSpec<Value>

  public var id: AnyHashable {
    AppGroupStoreKeyID(key: spec.key, store: spec.store)
  }

  public init(_ spec: AppGroupStoreSpec<Value>) where Value == Bool {
    self.init(shim: CastableShim(), spec: spec)
  }

  public init(_ spec: AppGroupStoreSpec<Value>) where Value == Int {
    self.init(shim: CastableShim(), spec: spec)
  }

  public init(_ spec: AppGroupStoreSpec<Value>) where Value == Double {
    self.init(shim: CastableShim(), spec: spec)
  }

  public init(_ spec: AppGroupStoreSpec<Value>) where Value == String {
    self.init(shim: CastableShim(), spec: spec)
  }

  public init(_ spec: AppGroupStoreSpec<Value>) where Value == URL {
    self.init(shim: URLShim(), spec: spec)
  }

  public init(_ spec: AppGroupStoreSpec<Value>) where Value == Data {
    self.init(shim: CastableShim(), spec: spec)
  }

  public init(_ spec: AppGroupStoreSpec<Value>) where Value: RawRepresentable, Value.RawValue == Int {
    self.init(shim: RawRepresentableShim(base: CastableShim()), spec: spec)
  }

  public init(_ spec: AppGroupStoreSpec<Value>) where Value: RawRepresentable, Value.RawValue == String {
    self.init(shim: RawRepresentableShim(base: CastableShim()), spec: spec)
  }

  public init(_ spec: AppGroupStoreSpec<Value>) where Value: Codable {
    self.init(shim: CodableShim(), spec: spec)
  }

  // MARK: - Optional Types

  public init(_ spec: AppGroupStoreSpec<Value>) where Value == Bool? {
    self.init(shim: OptionalShim(base: CastableShim()), spec: spec)
  }

  public init(_ spec: AppGroupStoreSpec<Value>) where Value == Int? {
    self.init(shim: OptionalShim(base: CastableShim()), spec: spec)
  }

  public init(_ spec: AppGroupStoreSpec<Value>) where Value == Double? {
    self.init(shim: OptionalShim(base: CastableShim()), spec: spec)
  }

  public init(_ spec: AppGroupStoreSpec<Value>) where Value == String? {
    self.init(shim: OptionalShim(base: CastableShim()), spec: spec)
  }

  public init(_ spec: AppGroupStoreSpec<Value>) where Value == URL? {
    self.init(shim: OptionalShim(base: URLShim()), spec: spec)
  }

  public init(_ spec: AppGroupStoreSpec<Value>) where Value == Data? {
    self.init(shim: OptionalShim(base: CastableShim()), spec: spec)
  }

  public init<R: RawRepresentable>(_ spec: AppGroupStoreSpec<Value>) where R.RawValue == Int, Value == R? {
    self.init(shim: OptionalShim(base: RawRepresentableShim(base: CastableShim())), spec: spec)
  }

  public init<R: RawRepresentable>(_ spec: AppGroupStoreSpec<Value>) where R.RawValue == String, Value == R? {
    self.init(shim: OptionalShim(base: RawRepresentableShim(base: CastableShim())), spec: spec)
  }

  private init(shim: any Shim<Value>, spec: AppGroupStoreSpec<Value>) where Value: Sendable {
    self.shim = shim
    self.spec = spec
  }
}

extension AppGroupStoreKey: PersistenceKey {

  public func load(initialValue: Value?) -> Value? {
    self.shim.loadValue(from: self.spec.store, at: self.spec.key, default: initialValue)
  }

  public func save(_ value: Value) {
    self.shim.saveValue(value, to: self.spec.store, at: self.spec.key)
  }

  public func subscribe(
    initialValue: Value?,
    didSet: @Sendable @escaping (_ newValue: Value?) -> Void
  ) -> Shared<Value>.Subscription {
    let userDefaultsDidChange = NotificationCenter.default.addObserver(
      forName: UserDefaults.didChangeNotification,
      object: self.spec.store,
      queue: nil
    ) { _ in
      guard !SharedAppGroupStoreLocal.isSetting else { return }
      didSet(load(initialValue: initialValue))
    }

    let willEnterForeground: (any NSObjectProtocol)?
    if let name = willEnterForegroundNotificationName() {
      willEnterForeground = NotificationCenter.default.addObserver(
        forName: name,
        object: nil,
        queue: nil
      ) { _ in
        didSet(load(initialValue: initialValue))
      }
    } else {
      willEnterForeground = nil
    }

    return Shared.Subscription {
      NotificationCenter.default.removeObserver(userDefaultsDidChange)
      if let willEnterForeground {
        NotificationCenter.default.removeObserver(willEnterForeground)
      }
    }
  }
}

private struct AppGroupStoreKeyID: Hashable {
  let key: String
  let store: UserDefaults
}

private var temporarySuiteName: String { "\(NSTemporaryDirectory())com.braysoftware.\(UUID().uuidString)" }
private var temporarySuite: UserDefaults { UserDefaults(suiteName: temporarySuiteName)! }

private enum DefaultPrivateAppGroupStoreKey: DependencyKey {
  static var testValue: UncheckedSendable<UserDefaults> { UncheckedSendable(temporarySuite) }
  static var previewValue: UncheckedSendable<UserDefaults> { Self.testValue }
  static var liveValue: UncheckedSendable<UserDefaults> { UncheckedSendable(UserDefaults.standard) }
}

private enum DefaultSharedAppGroupStoreKey: DependencyKey {
  static var testValue: UncheckedSendable<UserDefaults> { UncheckedSendable(temporarySuite) }
  static var previewValue: UncheckedSendable<UserDefaults> { Self.testValue }
  static var liveValue: UncheckedSendable<UserDefaults> { unimplemented("liveValue") }
}

extension DependencyValues {
  public var defaultPrivateAppGroupStore: UserDefaults {
    get { self[DefaultPrivateAppGroupStoreKey.self].value }
    set { self[DefaultPrivateAppGroupStoreKey.self].value = newValue }
  }

  public var defaultSharedAppGroupStore: UserDefaults {
    get { self[DefaultSharedAppGroupStoreKey.self].value }
    set { self[DefaultSharedAppGroupStoreKey.self].value = newValue }
  }
}

// NB: This is mainly used for tests, where observer notifications can bleed across cases.
private enum SharedAppGroupStoreLocal {
  @TaskLocal static var isSetting = false
}

private protocol Shim<Value> : Sendable {
  associatedtype Value

  func loadValue(from store: UserDefaults, at key: String, default defaultValue: Value?) -> Value?

  func saveValue(_ newValue: Value, to store: UserDefaults, at key: String)
}

private struct CodableShim<Value: Codable>: Shim {

  func loadValue(from store: UserDefaults, at key: String, default defaultValue: Value?) -> Value? {
    guard let data = store.object(forKey: key) as? Data else {
      SharedAppGroupStoreLocal.$isSetting.withValue(true) {
        if let data = try? defaultValue.encodedValue() {
          store.setValue(data, forKey: key)
        }
      }
      return defaultValue
    }
    return try! data.decodedValue()
  }

  func saveValue(_ newValue: Value, to store: UserDefaults, at key: String) {
    SharedAppGroupStoreLocal.$isSetting.withValue(true) {
      store.setValue(try! newValue.encodedValue(), forKey: key)
    }
  }
}

private struct CastableShim<Value>: Shim {

  func loadValue(from store: UserDefaults, at key: String, default defaultValue: Value?) -> Value? {
    guard let value = store.object(forKey: key) as? Value else {
      SharedAppGroupStoreLocal.$isSetting.withValue(true) {
        store.setValue(defaultValue, forKey: key)
      }
      return defaultValue
    }
    return value
  }

  func saveValue(_ newValue: Value, to store: UserDefaults, at key: String) {
    SharedAppGroupStoreLocal.$isSetting.withValue(true) {
      store.setValue(newValue, forKey: key)
    }
  }
}

/// Shim implementation tuned for URL values.
/// For URLs, dedicated UserDefaults APIs for getting/setting need to be called that convert the URL from/to Data.
/// Calling setValue with a URL causes a NSInvalidArgumentException exception.
private struct URLShim: Shim {
  typealias Value = URL

  func loadValue(from store: UserDefaults, at key: String, default defaultValue: URL?) -> URL? {
    guard let value = store.url(forKey: key) else {
      SharedAppGroupStoreLocal.$isSetting.withValue(true) {
        store.set(defaultValue, forKey: key)
      }
      return defaultValue
    }
    return value
  }

  func saveValue(_ newValue: URL, to store: UserDefaults, at key: String) {
    SharedAppGroupStoreLocal.$isSetting.withValue(true) {
      store.set(newValue, forKey: key)
    }
  }
}

private struct RawRepresentableShim<Value: RawRepresentable, Base: Shim>: Shim
where Value.RawValue == Base.Value {
  let base: Base

  func loadValue(from store: UserDefaults, at key: String, default defaultValue: Value?) -> Value? {
    base.loadValue(from: store, at: key, default: defaultValue?.rawValue)
      .flatMap(Value.init(rawValue:)) ?? defaultValue
  }

  func saveValue(_ newValue: Value, to store: UserDefaults, at key: String) {
    base.saveValue(newValue.rawValue, to: store, at: key)
  }
}

private struct OptionalShim<Base: Shim>: Shim {
  let base: Base

  func loadValue(from store: UserDefaults, at key: String, default defaultValue: Base.Value??) -> Base.Value?? {
    base.loadValue(from: store, at: key, default: defaultValue ?? nil)
  }

  func saveValue(_ newValue: Base.Value?, to store: UserDefaults, at key: String) {
    guard let newValue else {
      store.removeObject(forKey: key)
      return
    }
    base.saveValue(newValue, to: store, at: key)
  }
}


#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(WatchKit)
import WatchKit
#endif

fileprivate func willEnterForegroundNotificationName() -> Notification.Name? {
#if os(iOS) || os(tvOS) || os(visionOS)
  return UIApplication.willEnterForegroundNotification
#elseif os(macOS)
  return NSApplication.willBecomeActiveNotification
#else
  if #available(watchOS 7, *) {
    return WKExtension.applicationWillEnterForegroundNotification
  } else {
    return nil
  }
#endif
}
