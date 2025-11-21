// Copyright © 2025 Brad Howes. All rights reserved.

/**
 Custom script to create the `FluidR3_GM.sf2` soundfont file from 3 smaller parts, just to get out from using git-lfs
 on this repo.

 First argument is the path to this script. Last argument is the output file to generate.
 The remaining arguments are the pieces to concatenate to make the output file.
 */

import Foundation

let arguments = ProcessInfo().arguments
if arguments.count < 3 {
  print("BuldFluidFontCmd: missing arguments - \(arguments)")
  exit(1)
}

let first = URL(fileURLWithPath: arguments[1], isDirectory: false)
let output = URL(fileURLWithPath: arguments.last!, isDirectory: false)

if FileManager.default.fileExists(atPath: output.path()) {
  print("BuldFluidFontCmd: skipping -- \(output.path()) already exists")
  exit(0)
}

print("BuldFluidFontCmd: generating output - \(output)")

// Copy first part so we can get a `FileHandle` and then use that to append the others.
try FileManager.default.copyItem(at: first, to: output)

let fileHandle = FileHandle(forWritingAtPath: output.path())!
defer { fileHandle.closeFile() }
try fileHandle.seekToEnd()

for input in arguments[2..<arguments.count] {
  try fileHandle.write(contentsOf: Data(contentsOf: .init(filePath: input, directoryHint: .notDirectory)))
}
