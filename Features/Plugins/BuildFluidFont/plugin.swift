// Copyright © 2025 Brad Howes. All rights reserved.

/// Custom plugin that runs `BuildFluidFontCmd` to create the `FluidR3_GM.sf2` soundfont file.

import Foundation
import PackagePlugin

@main
struct BuildFluidFont: BuildToolPlugin {

  func createBuildCommands(
    context: PackagePlugin.PluginContext,
    target: any PackagePlugin.Target
  ) async throws -> [PackagePlugin.Command] {
    let input = target
      .directoryURL
      .deletingLastPathComponent()
      .appending(path: "SF2Resources/FluidR3_GM_Parts", directoryHint: .isDirectory)
    let inputs: [URL] = (1...3).map {
      .init(
        filePath: "FluidR3_GM.sf2.\($0)",
        directoryHint: .notDirectory,
        relativeTo: input
      )
    }
    let output = context
      .pluginWorkDirectoryURL
      .appendingPathComponent("FluidR3_GM.sf2")
    return [
      .buildCommand(
        displayName: "Generating FluidR3_GM file from parts",
        executable: try context.tool(named: "BuildFluidFontCmd").url,
        arguments: inputs.map(\.path) + [output.path()],
        inputFiles: inputs,
        outputFiles: [output])
    ]
  }
}
