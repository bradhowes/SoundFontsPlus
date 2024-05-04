import Foundation
import SwiftData

public extension PersistentIdentifier {

  static func fromData(_ data: Data) throws -> Self {
    let decoder = PropertyListDecoder()
    return try decoder.decode(PersistentIdentifier.self, from: data)
  }

  func toData() throws -> Data {
    let encoder = PropertyListEncoder()
    return try encoder.encode(self)
  }
}
