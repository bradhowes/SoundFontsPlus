import Dependencies
import Foundation
import SwiftData

/**
 Collection of SwiftData operations one can perform on a "database" regardless of operating environment.
 */
struct Database {
  var fetchMovies: @Sendable (FetchDescriptor<MovieModel>) -> [MovieModel]
  var add: @Sendable () -> MovieModel
  var delete: @Sendable (MovieModel) -> Void
  var save: @Sendable () -> Void
}

@Sendable
private func doFetchMovies(_ descriptor: FetchDescriptor<MovieModel>) -> [MovieModel] {
  @Dependency(\.modelContextProvider) var context
  return (try? context.fetch(descriptor)) ?? []
}

@Sendable
private func doAdd() -> MovieModel {
  @Dependency(\.modelContextProvider) var context
  return ActiveSchema.makeMock(context: context, entry: Support.nextMockMovieEntry(context: context))
}

@Sendable
private func doDelete(_ model: MovieModel) {
  @Dependency(\.modelContextProvider) var context
  context.delete(model)
  try? context.save()
}

@Sendable
private func doSave() {
  @Dependency(\.modelContextProvider) var context
  try? context.save()
}

extension DependencyValues {
  var database: Database {
    get { self[Database.self] }
    set { self[Database.self] = newValue }
  }
}

extension Database: DependencyKey {
  static let liveValue = Self(
    fetchMovies: doFetchMovies,
    add: doAdd,
    delete: doDelete,
    save: doSave
  )
}

// The test version is the same -- the differences are found in the underlying `ModelContainer`, so there is no need
// right now to differentiate.
extension Database: TestDependencyKey {
  static let testValue = Self(
    fetchMovies: doFetchMovies,
    add: doAdd,
    delete: doDelete,
    save: doSave
  )
}
