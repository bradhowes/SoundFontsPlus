import Foundation

class Helpers {}

func getSF2Resources() -> [URL] {
  let urls = Bundle.module.urls(forResourcesWithExtension: "sf2", subdirectory: nil)!
  return urls
}

func testURLForResource(_ resourceName: String) -> URL {
  return Bundle.module.url(forResource: resourceName, withExtension: nil)!
}

func dataFrom(resource: String) throws -> Data {
  let url = testURLForResource(resource)
  let data = try Data(contentsOf: url)
  return data
}

func stringFrom(resource: String) throws -> String {
  let url = testURLForResource(resource)
  let value = try String(contentsOfFile: url.path, encoding: String.Encoding.utf8)
  return value
}

