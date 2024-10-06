import Fakery
import Foundation
import SwiftData

enum Mock {

  static func makeSoundFont(
    context: ModelContext,
    name: String,
    presetNames: [String],
    tags: [TagModel] = []
  ) throws -> SoundFontModel {
    let soundFont = SoundFontModel(
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

    for tag in tags {
      tag.tag(soundFont: soundFont)
    }

    soundFont.tags = tags

    for presetName in presetNames {
      let preset = makePreset(context: context, owner: soundFont, name: presetName)
      soundFont.presets.append(preset)
    }

    try context.save()

    return soundFont
  }

  static func makePreset(context: ModelContext, owner: SoundFontModel, name: String) -> PresetModel {
    let index = owner.presets.count
    let preset = PresetModel(
      owner: owner,
      name: name,
      index: index,
      bank: index / 100,
      program: index % 100
    )

    context.insert(preset)
    try? context.save()

    return preset
  }

  static func generateMocks(context: ModelContext, count: Int) throws -> ModelContext {
    let faker = Faker(locale: "en-US")
    for _ in 0..<count {
      let name = faker.name.name()
      let presetNames = (0..<faker.number.randomInt(min: 10, max: 20)).map { _ in
        faker.lorem.sentences(amount: faker.number.randomInt(min: 1, max: 5))
      }
      _ = try makeSoundFont(context: context, name: name, presetNames: presetNames)
    }
    return context
  }
}
