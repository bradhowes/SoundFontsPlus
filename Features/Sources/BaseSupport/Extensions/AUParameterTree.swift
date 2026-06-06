// Copyright © 2025 Brad Howes. All rights reserved.

import AudioUnit.AUParameters
import CasePathsCore
import Dependencies

extension AUParameterTree {

  /**
   Access parameter in tree via ParameterAddressProvider (eg enum).

   - parameter address: the address to fetch
   - returns: the found value
   */
  @inlinable
  public subscript(address: ParameterAddress) -> AUParameter {
    // swiftlint:disable:next force_unwrapping
    parameter(withAddress: address.rawValue)!
  }
}
