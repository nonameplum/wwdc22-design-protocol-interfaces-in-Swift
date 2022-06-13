//: [Previous](@previous)

import Foundation

/*:
 # Hide implementation details
*/

protocol Animal {
  var isHungry: Bool { get }
}

extension Farm {
  var hungryAnimals: [any Animal] {
    animals.filter(\.isHungry)
  }

  func feedAnimals() {
    for animal in hungryAnimals {
      _ = animal
    }
  }
}

struct Farm {
  var animals: [any Animal]
}

/*:
 You might notice that `feedAnimals()` only iterates over the result of `hungryAnimals` once,

 and then immediately discards this temporary array. This is inefficient if the farm contains

 a large number of hungry animals.

 One way to avoid this temporary allocation is to use the standard library's `lazy collections feature.

 ```swift
 animals.lazy.filter(\.isHungry)
 ```

 A lazy collection has the same elements as the array returned by a plain call to `filter`,

 but it avoids the temporary allocation.
*/

extension Farm {
  var lazyHungryAnimals: LazyFilterSequence<[any Animal]> {
    animals.lazy.filter(\.isHungry)
  }
}

/*:
 However, now the type of the `hungryAnimals` property must be declared as this rather

 complex concrete type, `LazyFilterSequence<[any Animal]>`.

 This exposes an unnecessary implementation detail.

 The client, `feedAnimals()` doesn't care that we used `lazy.filter` in the implementation of `hungryAnimals`.

 It only needs to know that it's getting some collection that it can iterate over.
*/

extension Farm {
  var opaqueHungryAnimals: some Collection {
    animals.lazy.filter(\.isHungry)
  }
}

/*:
 An opaque result type can be used to hide the complex concrete type behind the abstract interface of a `Collection`.

 Now clients calling `opaqueHungryAnimals` only know they'are getting some concrete type

 conforming to the `Collection` protocol, but they don't know the specific concrete type of collection.
*/

extension Farm {
  func opaqueFeedAnimals() {
    for animal in opaqueHungryAnimals {
      // error: value of type '(some Collection).Element' has no member 'isHungry'
//     animal.isHungry
      _ = animal
    }
  }
}

/*:
 However as written, this actually hides too much static type information from the client.

 We're declaring that `opaqueHungryAnimals` outputs some concrete type conforming to `Collection`,

 but we don't know anything about this `Collection's` `Element` type.

 Without the knowledge that the element type is `any Animal`, all we can do with the element type

 is pass it around. We can't call any of the methods of the `Animal` protocol.
*/

/*:
 > `some Collection`
 >
 > We can strike the right balance between hiding implementation details and exposing
 >
 > a sufficiently-rich interface by using a constrained opaque result type.
 >
 > `some Collection<any Animal>`
 >
 > A constraint opaque result type is written by applying type arguments
 >
 > in angle brackets afer the procotol name.
*/

extension Farm {
  var constrainedOpaqueHungryAnimals: some Collection<any Animal> {
    animals.lazy.filter(\.isHungry)
  }
}

extension Farm {
  func constrainedOpaqueFeedAnimals() {
    for animal in constrainedOpaqueHungryAnimals {
      animal.isHungry
    }
  }
}

/*:
 Once `hungryAnimals` is declared with a constrained opaque result type,

 the fact that it is actually a `LazyFitlerSequence` of an array of `any Animal` is hidden from the client.

 But the client stil has the knowledge that it is some concrete type conforming to `Collection`,

 whose `Element` associated type is equal to `any Animal`.

 This all works because the Collection protocol declares that the `Element` associated type

 is a **primary associated type**.

 You can declare your own protocols with primary associated types by naming one or more associated types

 in angle brackets after the protocol name.
*/

protocol Sequence_ {
  associatedtype Iterator
}

protocol Collection_<Element>: Sequence_ {
  associatedtype Element
  associatedtype Iterator
}

/*:
 The associated types that work best as primary associated types are those that are usually provided

 by the caller, such as an `Element` type of a `Collection`, as opposed to implementation details,

 such as the collection's `Iterator` type.
*/

struct Array_<Element>: Collection_ {
  typealias Iterator = Any
}

struct Set_<Element>: Collection_ {
  typealias Iterator = Any
}

/*:
 Often, you will see a correspondence between the primary associated types of a protocol,

 and the generic parameters of a concrete type conforming to this protocol.

 Here you can see that the `Element` primary associated type of `Collection` is implemented

 by the `Element` generic paramter of `Array` and `Set`, two concrete types defined by the standard library

 that both conform to `Collection`.

 `some Collection<Element>` can be used with opaque result types using the `some` keyword,

 as well as `any Collection<Element> with constrained existential types using the `any` keyword.
*/

var ifLazy = false

extension Farm {
  var notMatchingHungryAnimals: some Collection<any Animal> {
    // error: function declares an opaque return type 'some Collection<any Animal>',
    // but the return statements in its body do not have matching underlying types
//    if ifLazy {
//      return animals.lazy.filter(\.isHungry)
//    } else {
//      return animals.filter(\.isHungry)
//    }
    return []
  }
}

/*:
 If we wanted `hungryAnimals` to have the option of whether to compute the `hungryAnimals` lazily

 or eagerly, using an opaque `Collection` of `any Animal` would result in an error that the function

 returns two different underlying types.
*/

extension Farm {
  var fixedHungryAnimals: any Collection<any Animal> {
    if ifLazy {
      return animals.lazy.filter(\.isHungry)
    } else {
      return animals.filter(\.isHungry)
    }
  }
}

/*:
 We can fix this by instead returing `any Collection` of `any Animal`, signaling that this API

 can return different types accross calls.

 The ability to constrain primary associated types gives opaque types and existential types

 a new level of expressivity.
*/

//: [Next](@next)
