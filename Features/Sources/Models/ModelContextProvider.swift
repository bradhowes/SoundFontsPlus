import Dependencies
import Foundation
import SwiftData

public typealias SoundFontId = String

public typealias ActiveSchema = SchemaV1
public typealias AudioSettingsModel = ActiveSchema.AudioSettingsModel
public typealias DelayConfigModel = ActiveSchema.DelayConfigModel
public typealias FavoriteModel = ActiveSchema.FavoriteModel
public typealias PresetModel = ActiveSchema.PresetModel
public typealias ReverbConfigModel = ActiveSchema.ReverbConfigModel
public typealias SoundFontModel = ActiveSchema.SoundFontModel
public typealias SoundFontInfoModel = ActiveSchema.SoundFontInfoModel
public typealias TagModel = ActiveSchema.TagModel

public struct TypedModelContextClient<Model: PersistentModel> : Sendable {
  public var insert: @Sendable (Model) -> Void
  public var fetch: @Sendable (FetchDescriptor<Model>) throws -> [Model]
  public var delete: @Sendable (Model) -> Void
}

public struct ModelContextClient : Sendable {
  public var save: @Sendable () throws -> Void
  public var soundsFonts: TypedModelContextClient<SoundFontModel>
  public var tags: TypedModelContextClient<TagModel>
  public var presets: TypedModelContextClient<PresetModel>
}

/**
 Wrapper around a `ModelContext` value that can be used for a dependency.
 */
public struct ModelContextProvider {
  /// The context to use for SwiftData operations
  public let context: ModelContext
}

extension DependencyValues {
  public var modelContextProvider: ModelContext {
    get { self[ModelContextKey.self] }
    set { self[ModelContextKey.self] = newValue }
  }
}

public enum ModelContextKey: DependencyKey {
  public static let liveValue = liveContext()
}

extension ModelContextKey: TestDependencyKey {
  public static var previewValue: ModelContext { previewContext() }
  public static var testValue: ModelContext { previewContext() }
//    unimplemented("ModelContextProvider testValue", placeholder: ModelContextKey.testValue)
//  }
}

@MainActor internal let liveContext: (() -> ModelContext) = {
  if ProcessInfo.processInfo.arguments.contains("UITEST") {
    print("UITEST context")
    return makeTestContext()
  }
  return liveContainer.mainContext
}

@MainActor private let previewContext: (() -> ModelContext) = {
  print("previewContext")
  return makeTestContext()
}

/// Create a ModelContainer to be used in a live environment.
func makeLiveContainer(dbFile: URL) -> ModelContainer {
  let schema = Schema(versionedSchema: ActiveSchema.self)
  let config = ModelConfiguration(schema: schema, url: dbFile, cloudKitDatabase: .none)
  // swiftlint:disable force_try
  return try! ModelContainer(for: schema, migrationPlan: MigrationPlan.self, configurations: config)
  // swiftlint:enable force_try
}

private let liveContainer: ModelContainer = makeLiveContainer(
  dbFile: URL.applicationSupportDirectory.appending(path: "Models.sqlite")
)

internal func makeTestContext() -> ModelContext {
  print("makeTestContainer")
  do {
    let context = try ModelContext(makeInMemoryContainer())
    return context
  } catch {
    fatalError(error.localizedDescription)
  }
}

internal func makeInMemoryContainer() throws -> ModelContainer {
  print("makeInMemoryContainer")
  let schema = Schema(versionedSchema: ActiveSchema.self)
  let config = ModelConfiguration(
    schema: schema,
    isStoredInMemoryOnly: true,
    groupContainer: .none,
    cloudKitDatabase: .none
  )
  return try ModelContainer(for: schema, migrationPlan: nil, configurations: config)
}

#if hasFeature(RetroactiveAttribute)
extension KeyPath: @unchecked @retroactive Sendable {}
extension ModelContext: @unchecked @retroactive Sendable {}
#else
extension KeyPath: @unchecked Sendable {}
extension ModelContext: @unchecked Sendable {}
#endif
