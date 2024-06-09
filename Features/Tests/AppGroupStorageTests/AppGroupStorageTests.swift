@_spi(Internals) import ComposableArchitecture
import Perception
import XCTest
import UserDefaultsStorage

final class UserDefaultsStorageTests: XCTestCase {
  func testBasics() {
    @Dependency(\.defaultUserDefaultsStorage) var defaults
    @Shared(.udStore("count")) var count = 0
    XCTAssertEqual(count, 0)
    XCTAssertEqual(defaults.integer(forKey: "count"), 0)

    count += 1
    XCTAssertEqual(count, 1)
    XCTAssertEqual(defaults.integer(forKey: "count"), 1)
  }

  func testDefaultsRegistered() {
    @Dependency(\.defaultUserDefaultsStorage) var defaults
    @Shared(.udStore("count")) var count = 42
    XCTAssertEqual(defaults.integer(forKey: "count"), 42)

    count += 1
    XCTAssertEqual(count, 43)
    XCTAssertEqual(defaults.integer(forKey: "count"), 43)
  }

  func testDefaultsRegistered_Optional() {
    @Dependency(\.defaultUserDefaultsStorage) var defaults
    @Shared(.udStore("data")) var data: Data?
    XCTAssertEqual(defaults.data(forKey: "data"), nil)

    data = Data()
    XCTAssertEqual(data, Data())
    XCTAssertEqual(defaults.data(forKey: "data"), Data())
  }

  func testDefaultsRegistered_RawRepresentable() {
    enum Direction: String, CaseIterable {
      case north, south, east, west
    }
    @Dependency(\.defaultUserDefaultsStorage) var defaults
    @Shared(.udStore("direction")) var direction: Direction = .north
    XCTAssertEqual(defaults.string(forKey: "direction"), "north")

    direction = .south
    XCTAssertEqual(defaults.string(forKey: "direction"), "south")
  }

  func testDefaultsRegistered_Optional_RawRepresentable() {
    enum Direction: String, CaseIterable {
      case north, south, east, west
    }
    @Dependency(\.defaultUserDefaultsStorage) var defaults
    @Shared(.udStore("direction")) var direction: Direction?
    XCTAssertEqual(defaults.string(forKey: "direction"), nil)

    direction = .south
    XCTAssertEqual(defaults.string(forKey: "direction"), "south")
  }

  func testdefaultUserDefaultsStorageOverride() {
    let defaults = UserDefaults(suiteName: "tests")!
    defaults.removePersistentDomain(forName: "tests")

    withDependencies {
      $0.defaultUserDefaultsStorage = defaults
    } operation: {
      @Shared(.udStore("count")) var count = 0
      count += 1
      XCTAssertEqual(defaults.integer(forKey: "count"), 1)
    }

    @Dependency(\.defaultUserDefaultsStorage) var defaultUserDefaultsStorage
    XCTAssertNotEqual(defaultUserDefaultsStorage, defaults)
    XCTAssertEqual(defaultUserDefaultsStorage.integer(forKey: "count"), 0)
  }

  func testObservation_DirectMutation() {
    @Shared(.udStore("count")) var count = 0
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
    @Dependency(\.defaultUserDefaultsStorage) var defaults
    @Shared(.udStore("count")) var count = 0
    let didChange = self.expectation(description: "didChange")

    withObservationTracking {
      _ = count
    } onChange: { [count = $count] in
      XCTAssertEqual(count.wrappedValue, 0)
      didChange.fulfill()
    }

    defaults.setValue(42, forKey: "count")
    self.wait(for: [didChange], timeout: 0)
    XCTAssertEqual(count, 42)
  }

  func testChangeUserDefaultsDirectly() {
    @Dependency(\.defaultUserDefaultsStorage) var defaults
    @Shared(.udStore("count")) var count = 0
    defaults.setValue(count + 42, forKey: "count")
    XCTAssertEqual(count, 42)
  }

  func testChangeUserDefaultsDirectly_RawRepresentable() {
    enum Direction: String, CaseIterable {
      case north, south, east, west
    }
    @Dependency(\.defaultUserDefaultsStorage) var defaults
    @Shared(.udStore("direction")) var direction: Direction = .south
    defaults.set("east", forKey: "direction")
    XCTAssertEqual(direction, .east)
  }

  func testChangeUserDefaultsDirectly_KeyWithPeriod() {
    @Dependency(\.defaultUserDefaultsStorage) var defaults
    @Shared(.udStore("pointfreeco.count")) var count = 0
    defaults.setValue(count + 42, forKey: "pointfreeco.count")
    XCTAssertEqual(count, 42)
  }

  func testDeleteUserDefault() {
    @Dependency(\.defaultUserDefaultsStorage) var defaults
    @Shared(.udStore("count")) var count = 0
    count = 42
    defaults.removeObject(forKey: "count")
    XCTAssertEqual(count, 0)
  }

  func testKeyPath() {
    @Dependency(\.defaultUserDefaultsStorage) var defaults
    @Shared(.udStore(\.count)) var count = 0
    defaults.count += 1
    XCTAssertEqual(count, 1)
  }

  func testOptionalInitializers() {
    @Shared(.udStore("count1")) var count1: Int?
    XCTAssertEqual(count1, nil)
    @Shared(.udStore("count")) var count2: Int? = nil
    XCTAssertEqual(count2, nil)
  }

  func testSpecWithDefaultStore() {
    @Shared(.udStore(.count1)) var count1: Int?
    XCTAssertEqual(count1, nil)
    @Shared(.udStore(.count)) var count2: Int? = nil
    XCTAssertEqual(count2, nil)
  }

  func testSpecWithCustomStore() {
    @Shared(.udStore(.count1Alt)) var count1: Int?
    XCTAssertEqual(count1, nil)
    @Shared(.udStore(.countAlt)) var count2: Int? = nil
    XCTAssertEqual(count2, nil)
  }

  func testSpecWIthCustomStoresHoldSeparateValues() {
    @Dependency(\.defaultUserDefaultsStorage) var defaults
    @Dependency(\.customUserDefaultsStore) var defaultsAlt

    @Shared(.udStore(.count)) var count: Int?
    XCTAssertEqual(count, nil)
    @Shared(.udStore(.countAlt)) var countAlt: Int?
    XCTAssertEqual(count, nil)

    count = 123

    XCTAssertEqual(defaults.integer(forKey: "count"), 123)
    XCTAssertEqual(defaultsAlt.integer(forKey: "count"), 0)

    defaultsAlt.set(987, forKey: "count")
    XCTAssertEqual(countAlt, 987)
    XCTAssertEqual(count, 123)
  }
}

extension UserDefaultsKeyStoreSpec {
  static var count: UserDefaultsKeyStoreSpec<Optional<Int>> { .init("count") }
  static var countAlt: UserDefaultsKeyStoreSpec<Optional<Int>> { .init("count", store: \.customUserDefaultsStore) }
  static var count1: UserDefaultsKeyStoreSpec<Optional<Int>> { .init("count1") }
  static var count1Alt: UserDefaultsKeyStoreSpec<Optional<Int>> { .init("count1", store: \.customUserDefaultsStore) }
}

private enum CustomUserDefaultsStoreKey: DependencyKey {

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
  public var customUserDefaultsStore: UserDefaults {
    get { self[CustomUserDefaultsStoreKey.self].value }
    set { self[CustomUserDefaultsStoreKey.self].value = newValue }
  }
}



extension UserDefaults {
  @objc fileprivate dynamic var count: Int {
    get { integer(forKey: "count") }
    set { set(newValue, forKey: "count") }
  }
}
