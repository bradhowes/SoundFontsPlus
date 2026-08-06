// Copyright © 2025 Brad Howes. All rights reserved.

public import AudioUnit.AUParameters
import CasePathsCore
import Dependencies
import Engine

extension AUParameterTree {

  /**
   Access parameter in tree via `ParameterAddress` enum.

   - parameter address: the address to fetch
   - returns: the current value
   */
  public subscript(address: ParameterAddress) -> AUParameter? {
    parameter(withAddress: address.rawValue)
  }

  /**
   Access parameter in tree via `SF2.Render.Engine.ParameterAddress` enum (C++).

   - parameter address: the address to fetch
   - returns: the current value
   */
  public subscript(address: SF2.Render.Engine.ParameterAddress) -> AUParameter? {
    parameter(withAddress: address.rawValue)
  }

  /**
   Access parameter in tree via `SF2.Entity.Generator.Index` enum (C++).

   - parameter address: the address to fetch
   - returns: the current value
   */
  public subscript(address: SF2.Entity.Generator.Index) -> AUParameter? {
    parameter(withAddress: AUParameterAddress(address.rawValue))
  }
}
