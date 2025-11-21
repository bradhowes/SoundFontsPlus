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

    // Create file URLs to the parts to concatenate to create the final file. The `target` is a Swift Package target
    // which has a `plugins:["BuildFluidFont"]` value in its definition, like:
    //
    // .target(
    //   name: "SF2Resources",
    //   dependencies: [
    //     .product(name: "Engine", package: "SF2Lib"),
    //   ],
    //   resources: [.process("Resources")],
    //   plugins: ["BuildFluidFont"]
    // ),
    print("target.directoryURL: \(target.directoryURL)")
    let inputDirectory = target
      .directoryURL
      .appending(path: "FluidR3_GM_Parts", directoryHint: .isDirectory)
    let inputs: [URL] = (1...3).map {
      .init(
        filePath: "FluidR3_GM.sf2.\($0)",
        directoryHint: .notDirectory,
        relativeTo: inputDirectory
      )
    }
    print("inputs: \(inputs)")

    // Create output destination file URL in the plugin's work directory. This acts as a a cache of the build and will
    // only be regenerated if a dependency changes. The build system will actually perform an additional copy of this
    // file into the target's bundle when it generates the target.
    let output = context
      .pluginWorkDirectoryURL
      .appendingPathComponent("FluidR3_GM.sf2")
    print("output: \(output)")

    // Finally, create a Swift command to generate the output from the inputs if necessary during a build.
    let commands = [
      Command.buildCommand(
        displayName: "Generating FluidR3_GM file from parts",
        executable: try context.tool(named: "BuildFluidFontCmd").url,
        arguments: inputs.map(\.path) + [output.path()],
        inputFiles: inputs,
        outputFiles: [output])
    ]
    print("commands: \(commands)")
    return commands
  }
}
