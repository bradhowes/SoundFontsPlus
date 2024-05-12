import Foundation

/// Types of SF2 load failures
public enum SF2LoadFailure: Error {
  /// File is empty
  case emptyFile(_ file: String)
  /// File contents is not in SF2 format
  case invalidFile(_ file: String)
  /// Could not make a copy of the file
  case unableToCreateFile(_ file: String)
  /// SwiftData issue
  case swiftDataFailure(_ file: String, error: String)
}

extension SF2LoadFailure {

  var id: Int {
    switch self {
    case .emptyFile: return 1
    case .invalidFile: return 2
    case .unableToCreateFile: return 3
    case .swiftDataFailure: return 4
    }
  }

  var file: String {
    switch self {
    case .emptyFile(let file): return file
    case .invalidFile(let file): return file
    case .unableToCreateFile(let file): return file
    case .swiftDataFailure(let file, _): return file
    }
  }
}

extension SF2LoadFailure: Hashable {
  public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension SF2LoadFailure: Equatable {
  public static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}
