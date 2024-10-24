import Dependencies
import Fakery
import Foundation
import SwiftData

public enum Mock {

  public static func makeSoundFont(
    name: String,
    presetNames: [String],
    tags: [TagModel] = []
  ) throws -> SoundFontModel {
    @Dependency(\.modelContextProvider) var context
    @Dependency(\.uuid) var uuid

    let soundFont = SoundFontModel(
      key: .init(uuid()),
      name: name,
      location: .init(kind: .external, url: nil, raw: nil),
      info: .init(
        originalName: name,
        embeddedName: name,
        embeddedComment: "",
        embeddedAuthor: "",
        embeddedCopyright: ""
      )
    )

    context.insert(soundFont)
    try? context.save()

    for tag in tags {
      tag.tag(soundFont: soundFont)
    }

    soundFont.tags = tags

    for presetName in presetNames {
      let preset = makePreset(owner: soundFont, name: presetName)
      soundFont.presets.append(preset)
    }

    try context.save()

    return soundFont
  }

  public static func makePreset(owner: SoundFontModel, name: String) -> PresetModel {
    @Dependency(\.modelContextProvider) var context
    let index = owner.presets.count
    let preset = PresetModel(
      owner: owner,
      presetIndex: index,
      name: name,
      bank: index / 100,
      program: index % 100
    )

    context.insert(preset)
    try? context.save()

    return preset
  }

  public static func generateMocks(context: ModelContext, count: Int) throws -> ModelContext {
    let faker = Faker(locale: "en-US")
    for _ in 0..<count {
      let name = faker.name.name()
      let presetNames = (0..<faker.number.randomInt(min: 10, max: 20)).map { _ in
        faker.lorem.sentences(amount: faker.number.randomInt(min: 1, max: 5))
      }
      _ = try makeSoundFont(name: name, presetNames: presetNames)
    }
    return context
  }
}
