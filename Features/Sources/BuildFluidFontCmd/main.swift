/// Custom script to create the `FluidR3_GM.sf2` soundfont file from the given N slices
///
/// First argument is the path to this script. Last argument is the output file to generate.
/// The remaining arguments are the pieces to concatenate to make the output file.

import Foundation

let arguments = ProcessInfo().arguments
if arguments.count < 3 {
  print("missing arguments - \(arguments)")
  exit(1)
}

let output = URL(fileURLWithPath: arguments.last!)
if FileManager.default.fileExists(atPath: output.path()) {
  print("skipping -- \(output) already exists")
  exit(0)
}

for input in arguments.dropFirst().dropLast() {
  try! Data(contentsOf: .init(filePath: input, directoryHint: .notDirectory)).appendTo(output)
}

extension Data {

  func appendTo(_ fileURL: URL) throws {
    if let fileHandle = FileHandle(forWritingAtPath: fileURL.path) {
      defer {
        fileHandle.closeFile()
      }
      fileHandle.seekToEndOfFile()
      fileHandle.write(self)
    }
    else {
      try write(to: fileURL, options: .atomic)
    }
  }
}
