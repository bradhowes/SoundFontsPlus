import UIKit
import Tagged

struct Foo {
  typealias ID = Tagged<Self, Int>
  let id: ID
}

struct Bar {
  typealias ID = Tagged<Self, Int>
  let id: ID
}

let a = Foo(id: 1)
let b = Bar(id: 1)
