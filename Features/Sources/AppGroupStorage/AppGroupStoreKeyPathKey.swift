import ComposableArchitecture
import Dependencies
import Foundation


extension PersistenceReaderKey {

  public static func appGroupStore<Value>(
    _ keyPath: ReferenceWritableKeyPath<UserDefaults, Value>,
    store: KeyPath<DependencyValues, UserDefaults>
  ) -> Self where Self == AppGroupStoreKeyPathKey<Value> {
    AppGroupStoreKeyPathKey(keyPath, store: store)
  }
}

public struct AppGroupStoreKeyPathKey<Value> where Value: Sendable {
  private let keyPath: ReferenceWritableKeyPath<UserDefaults, Value>
  private let store: UserDefaults

  public init(
    _ keyPath: ReferenceWritableKeyPath<UserDefaults, Value>,
    store: KeyPath<DependencyValues, UserDefaults>
  ) {
    @Dependency(store) var storage
    self.keyPath = keyPath
    self.store = storage
  }
}

extension AppGroupStoreKeyPathKey: PersistenceKey, Hashable {

  public func load(initialValue _: Value?) -> Value? {
    self.store[keyPath: self.keyPath]
  }

  public func save(_ newValue: Value) {
    SharedAppGroupStoreLocals.$isSetting.withValue(true) {
      self.store[keyPath: self.keyPath] = newValue
    }
  }

  public func subscribe(
    initialValue: Value?,
    didSet: @Sendable @escaping (_ newValue: Value?) -> Void
  ) -> Shared<Value>.Subscription {
    let observer = self.store.observe(self.keyPath, options: .new) { _, change in
      guard
        !SharedAppGroupStoreLocals.isSetting
      else { return }
      didSet(change.newValue ?? initialValue)
    }
    return Shared.Subscription {
      observer.invalidate()
    }
  }

  private class Observer: NSObject {
    let didChange: (Value?) -> Void
    init(didChange: @escaping (Value?) -> Void) {
      self.didChange = didChange
      super.init()
    }
    override func observeValue(
      forKeyPath keyPath: String?,
      of object: Any?,
      change: [NSKeyValueChangeKey: Any]?,
      context: UnsafeMutableRawPointer?
    ) {
      self.didChange(change?[.newKey] as? Value)
    }
  }
}

// NB: This is mainly used for tests, where observer notifications can bleed across cases.
private enum SharedAppGroupStoreLocals {
  @TaskLocal static var isSetting = false
}
