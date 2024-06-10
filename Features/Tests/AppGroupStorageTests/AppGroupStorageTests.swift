@_spi(Internals) import ComposableArchitecture
import Perception
import XCTest
import AppGroupStorage


final class AppGroupStorageTests: XCTestCase {

  func testBasics() {
    let key: String = .count
    @Dependency(\.defaultPrivateAppGroupStore) var defaults
    @Shared(.appGroupStore(key, store: \.defaultPrivateAppGroupStore)) var count = 0
    XCTAssertEqual(count, 0)
    XCTAssertEqual(defaults.integer(forKey: key), 0)

    count += 1
    XCTAssertEqual(count, 1)
    XCTAssertEqual(defaults.integer(forKey: key), 1)
  }

  func testDefaultsRegistered() {
    let key: String = .count
    @Dependency(\.defaultPrivateAppGroupStore) var defaults
    @Shared(.appGroupStore(key, store: \.defaultPrivateAppGroupStore)) var count = 42
    XCTAssertEqual(defaults.integer(forKey: key), 42)

    count += 1
    XCTAssertEqual(count, 43)
    XCTAssertEqual(defaults.integer(forKey: key), 43)
  }

  func testDefaultsRegistered_Optional() {
    let key: String = .data
    @Dependency(\.defaultPrivateAppGroupStore) var defaults
    @Shared(.appGroupStore(key, store: \.defaultPrivateAppGroupStore)) var data: Data?
    XCTAssertEqual(defaults.data(forKey: key), nil)

    data = Data()
    XCTAssertEqual(data, Data())
    XCTAssertEqual(defaults.data(forKey: key), Data())
  }

  func testDefaultsRegistered_RawRepresentable() {
    let key: String = .direction
    enum Direction: String, CaseIterable {
      case north, south, east, west
    }
    @Dependency(\.defaultPrivateAppGroupStore) var defaults
    @Shared(.appGroupStore(key, store: \.defaultPrivateAppGroupStore)) var direction: Direction = .north
    XCTAssertEqual(defaults.string(forKey: key), "north")

    direction = .south
    XCTAssertEqual(defaults.string(forKey: key), "south")
  }

  func testDefaultsRegistered_Codable() {
    let key: String = .codable
    @Dependency(\.defaultPrivateAppGroupStore) var defaults
    @Shared(.appGroupStore(key, store: \.defaultPrivateAppGroupStore)) var codable: CodableCheck = CodableCheck()
    XCTAssertEqual(try? defaults.data(forKey: key)?.decodedValue(), CodableCheck())

    let update = CodableCheck(a: 234, b: "222", c: 2.1718)
    codable = update
    XCTAssertEqual(try? defaults.data(forKey: key)?.decodedValue(), update)

    @Shared(.appGroupStore(key, store: \.defaultPrivateAppGroupStore)) var codable2: CodableCheck = CodableCheck()
    XCTAssertEqual(codable, codable2)
  }

  func testDefaultsRegistered_Optional_Codable() {
    let key: String = .optionalCodable
    @Dependency(\.defaultPrivateAppGroupStore) var defaults
    @Shared(.appGroupStore(key, store: \.defaultPrivateAppGroupStore)) var codable: CodableCheck?
    let raw = defaults.data(forKey: key)
    XCTAssertNil(raw)

    let newValue = CodableCheck(a: 234, b: "222", c: 2.1718)
    codable = newValue
    XCTAssertEqual(try? defaults.data(forKey: key)?.decodedValue(), newValue)

    @Shared(.appGroupStore(key, store: \.defaultPrivateAppGroupStore)) var codable2: CodableCheck?
    XCTAssertEqual(codable, codable2)
  }

  func testDefaultsRegistered_Optional_RawRepresentable() {
    let key: String = .direction
    enum Direction: String, CaseIterable {
      case north, south, east, west
    }
    @Dependency(\.defaultPrivateAppGroupStore) var defaults
    @Shared(.appGroupStore(key, store: \.defaultPrivateAppGroupStore)) var direction: Direction?
    XCTAssertEqual(defaults.string(forKey: key), nil)

    direction = .south
    XCTAssertEqual(defaults.string(forKey: key), "south")
  }

  func testdefaultPrivateAppGroupStoreOverride() {
    let defaults = UserDefaults(suiteName: "tests")!
    defaults.removePersistentDomain(forName: "tests")

    withDependencies {
      $0.defaultPrivateAppGroupStore = defaults
    } operation: {
      @Shared(.appGroupStore(.count, store: \.defaultPrivateAppGroupStore)) var count = 0
      count += 1
      XCTAssertEqual(defaults.integer(forKey: .count), 1)
    }

    @Dependency(\.defaultPrivateAppGroupStore) var store
    XCTAssertNotEqual(store, defaults)
    XCTAssertEqual(store.integer(forKey: .count), 0)
  }

  func testObservation_DirectMutation() {
    @Shared(.appGroupStore(.count, store: \.defaultPrivateAppGroupStore)) var count = 0
    let countDidChange = self.expectation(description: "countDidChange")
    withObservationTracking {
      _ = count
    } onChange: {
      countDidChange.fulfill()
    }
    count += 1
    self.wait(for: [countDidChange], timeout: 0)
  }

  func testObservation_ExternalMutation() {
    @Dependency(\.defaultPrivateAppGroupStore) var defaults
    @Shared(.appGroupStore(.count, store: \.defaultPrivateAppGroupStore)) var count = 0
    let didChange = self.expectation(description: "didChange")

    withObservationTracking {
      _ = count
    } onChange: { [count = $count] in
      XCTAssertEqual(count.wrappedValue, 0)
      didChange.fulfill()
    }

    defaults.setValue(42, forKey: .count)
    self.wait(for: [didChange], timeout: 0)
    XCTAssertEqual(count, 42)
  }

  func testChangeUserDefaultsDirectly() {
    @Dependency(\.defaultPrivateAppGroupStore) var defaults
    @Shared(.appGroupStore(.count, store: \.defaultPrivateAppGroupStore)) var count = 0
    defaults.setValue(count + 42, forKey: .count)
    XCTAssertEqual(count, 42)
  }

  func testChangeUserDefaultsDirectly_RawRepresentable() {
    enum Direction: String, CaseIterable {
      case north, south, east, west
    }
    @Dependency(\.defaultPrivateAppGroupStore) var defaults
    @Shared(.appGroupStore(.direction, store: \.defaultPrivateAppGroupStore)) var direction: Direction = .south
    defaults.set("east", forKey: .direction)
    XCTAssertEqual(direction, .east)
  }

  func testChangeUserDefaultsDirectly_KeyWithPeriod() {
    @Dependency(\.defaultPrivateAppGroupStore) var defaults
    @Shared(.appGroupStore("pointfreeco.count", store: \.defaultPrivateAppGroupStore)) var count = 0
    defaults.setValue(count + 42, forKey: "pointfreeco.count")
    XCTAssertEqual(count, 42)
  }

  func testDeleteUserDefault() {
    @Dependency(\.defaultPrivateAppGroupStore) var defaults
    @Shared(.appGroupStore(.count, store: \.defaultPrivateAppGroupStore)) var count = 0
    count = 42
    defaults.removeObject(forKey: .count)
    XCTAssertEqual(count, 0)
  }

  func testKeyPath() {
    @Dependency(\.defaultSharedAppGroupStore) var defaults
    @Shared(.appGroupStore(.doubleValue, store: \.defaultSharedAppGroupStore)) var value: Double = 0.0
    defaults.doubleValue += 1
    XCTAssertEqual(value, 1)
  }

  func testOptionalInitializers() {
    @Shared(.appGroupStore(.count1, store: \.defaultPrivateAppGroupStore)) var count1: Int?
    XCTAssertEqual(count1, nil)
    @Shared(.appGroupStore(.count2, store: \.defaultPrivateAppGroupStore)) var count2: Int? = nil
    XCTAssertEqual(count2, nil)
  }

  func testSpecWithDefaultStore() {
    @Shared(.appGroupStore(.count1)) var count1: Int = 0
    XCTAssertEqual(count1, 0)
    @Shared(.appGroupStore(.count2)) var count2: Int? = nil
    XCTAssertEqual(count2, nil)
  }

  func testSpecWithCustomStore() {
    @Shared(.appGroupStore(.count1Alt)) var count1: Int?
    XCTAssertEqual(count1, nil)
    @Shared(.appGroupStore(.count2Alt)) var count2: Int? = nil
    XCTAssertEqual(count2, nil)
  }

  func testSpecWIthCustomStoresHoldSeparateValues() {
    @Dependency(\.defaultSharedAppGroupStore) var defaults
    @Dependency(\.customStore) var defaultsAlt

    @Shared(.appGroupStore(.count1)) var count1: Int = 0
    XCTAssertEqual(count1, 0)
    @Shared(.appGroupStore(.count1Alt)) var count1Alt: Int?
    XCTAssertEqual(count1Alt, nil)

    count1 = 123

    XCTAssertEqual(defaults.integer(forKey: .count1), 123)
    XCTAssertEqual(defaultsAlt.integer(forKey: .count1), 0)

    defaultsAlt.set(987, forKey: .count1)
    XCTAssertEqual(count1Alt, 987)
    XCTAssertEqual(count1, 123)
  }
}

fileprivate extension String {
  static let doubleValue = "doubleValue"
  static let count = "count"
  static let count1 = "count1"
  static let count2 = "count2"
  static let data = "data"
  static let direction = "direction"
  static let codable = "codable"
  static let optionalCodable = "optionalCodable"
}

extension AppGroupStoreSpec {
  static var doubleValue: AppGroupStoreSpec<Double> { .init(.doubleValue, store: \.defaultSharedAppGroupStore) }
  static var count1: AppGroupStoreSpec<Int> { .init(.count1, store: \.defaultSharedAppGroupStore) }
  static var count1Alt: AppGroupStoreSpec<Optional<Int>> { .init(.count1, store: \.customStore) }
  static var count2: AppGroupStoreSpec<Optional<Int>> { .init(.count2, store: \.defaultSharedAppGroupStore) }
  static var count2Alt: AppGroupStoreSpec<Optional<Int>> { .init(.count2, store: \.customStore) }
}

private enum CustomStoreKey: DependencyKey {

  // Provide a unique container for every test
  static var testValue: UncheckedSendable<UserDefaults> {
    UncheckedSendable(
      UserDefaults(
        suiteName:
          "\(NSTemporaryDirectory())com.braysoftware.\(UUID().uuidString)"
      )!
    )
  }

  // Provide a unique container for every preview
  static var previewValue: UncheckedSendable<UserDefaults> {
    Self.testValue
  }

  static var liveValue: UncheckedSendable<UserDefaults> {
    UncheckedSendable(UserDefaults.standard)
  }
}

extension DependencyValues {
  public var customStore: UserDefaults {
    get { self[CustomStoreKey.self].value }
    set { self[CustomStoreKey.self].value = newValue }
  }
}

extension UserDefaults {
  @objc fileprivate dynamic var doubleValue: Double {
    get { double(forKey: .doubleValue) }
    set { set(newValue, forKey: .doubleValue) }
  }
}

fileprivate struct CodableCheck: Codable, Equatable {
  var a: Int = 1
  var b: String = "two"
  var c: Double = 3.14159
}
