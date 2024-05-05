import Foundation
import SwiftData

extension Data {

  /**
   Convert contents into an entity of type T that is decodable.

   - returns: entity that was previously encoded
   - throws if unable to decode contents
   */
  public func decodedValue<T: Decodable>() throws -> T {
    let decoder = PropertyListDecoder()
    return try decoder.decode(T.self, from: self)
  }
}

extension Encodable {

  /**
   Converts entity that is encodable into a Data collection.

   - returns: container holding representation of an encodable entity.
   - throws if unable to encode contents
   */
  public func encodedValue() throws -> Data {
    let encoder = PropertyListEncoder()
    return try encoder.encode(self)
  }
}
