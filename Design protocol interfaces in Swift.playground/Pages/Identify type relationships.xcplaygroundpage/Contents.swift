//: [Previous](@previous)

import Foundation

/*:
 # Identify type relationships

 Writing generic code using opaque types must rely on abstract type relationships.
*/

protocol Animal {
  var isHungry: Bool { get }

  associatedtype FeedType: AnimalFeed
  func eat(_: FeedType)
}

protocol AnimalFeed {}

protocol Crop {}

/*:
 The first set of conrete types.
*/

struct Cow: Animal {
  var isHungry: Bool
  func eat(_ feed: Hay) { print(type(of: self), #function, feed) }
}

struct Hay: AnimalFeed {
  static func grow() -> Alfalfa { Alfalfa() }
}

struct Alfalfa: Crop {
  func harvest() -> Hay { Hay() }
}

let cow: Cow = Cow(isHungry: true)

/*:
 Before we can feed an animal, we must grow the appropriate type of crop
 */

let alfalfa = Hay.grow()

/*:
 And harvest the crop to produce the feed.
*/

let hay = alfalfa.harvest()

cow.eat(hay)

/*:
 The second set of conrete types.
*/

struct Chicken: Animal {
  var isHungry: Bool
  func eat(_ feed: Scratch) { print(type(of: self), #function, feed) }
}

struct Scratch: AnimalFeed {
  static func grow() -> Millet { Millet() }
}

struct Millet: Crop {
  func harvest() -> Scratch { Scratch() }
}

/*:
 A chicken eats scratch
*/

let chicken: Chicken = Chicken(isHungry: true)

/*:
 We first need to grow a type of grain called millet
*/

let millet = Scratch.grow()

/*:
 That we harvest and process to produce chicken scratch
*/

let scratch = millet.harvest()

/*:
 Which we feed to our chicken.
*/

chicken.eat(scratch)

/*:
 I want to abstract over these two sets of related types, so I can implement the `feedAnimal` method once,

 and have it feed both cows and chickens, as well as any new types of animals I might adopt in the future.
*/

struct Farm {
  var animals: [any Animal]

  var hungryAnimals: some Collection<any Animal> {
    animals.lazy.filter(\.isHungry)
  }
}

extension Farm {
  func feedAnimals() {
    for animal in hungryAnimals {
       //feedAnimal(animal)
    }
  }

  private func feedAnimal(_ animal: some Animal) {
    // ???
  }
}

/*:
 Since `feedAnimal()` needs to work with the `eat()` method of the `Animal` protocol,

 which has an associated type in consuming position, I'm going to unbox the existential

 by declaring that the `feedAnimal()` method takes `some Animal` as a parameter type.

 To start, I'll define a pair of protocols, `AnimalFeed` and `Crop`,

 using what we know about protocols and associatedtypes so far.
*/

protocol AnimalFeed_ {
  associatedtype CropType: Crop_
  static func grow() -> CropType
}

protocol Crop_ {
  associatedtype FeedType: AnimalFeed_
  func harvest() -> FeedType
}

/*:
 `AnimalFeed` has an associated `CropType`, which conforms to `Crop`,

 and `Crop` has an associated `FeedType`, which conforms to `AnimalFeed`.

 ```
                    .CropType                       .FeedType
 [Self: AnimalFeed] ────────► [Self.CropType: Crop] ────────► [Self.CropType.FeedType: AnimalFeed]
              ▲                                                 |
              |                                                 | .CropType
              |   .FeedType                                     ▼
            [...] ◄──────── [Self.CropType.FeedType.CropType: Crop]
 ```

 In fact, this back-and-forth continues forever, with an infinite nesting of associated types

 that alternate between conforming to `AnimalFeed` and `Crop`.

 With the `Crop` protocol, we have a similar situation, just shifted by one.

 ```
              .FeedType                             .CropType
 [Self: Crop] ────────► [Self.FeedType: AnimalFeed] ────────► [Self.FeedType.CropType: Crop]
          ▲                                                      |
          |                                                      | .FeedType
          |   .CropType                                          ▼
        [...] ◄──────── [Self.FeedType.CropType.FeedType: AnimalFeed]
 ```

 Let's see if these protocols correctly model the relationship between our concrete types.
*/

protocol Animal_ {
  var isHungry: Bool { get }

  associatedtype FeedType: AnimalFeed_
  func eat(_: FeedType)
}

extension Farm {
  private func feedAnimal_(_ animal: some Animal_) {
    //                                         .FeedType
    // type(of: animal) -> some Animal: Animal ────────► (some Animal).FeedType: AnimalFeed
    // grow() -> (some Animal).FeedType.CropType: Crop
    let crop = type(of: animal).FeedType.grow()
    // harvest() -> (some Animal).FeedType.CropType.FeedType: AnimalFeed
    let feed = crop.harvest()
    // eat() on `(some Animal)` expects (some Animal).FeedType != (some Animal).FeedType.CropType.FeedType
//    animal.eat(feed)
  }
}

/*:
 Unfortunately, the `harvest()` result type `(some Animal).FeedType.CropType.FeedType` this is the wrong type.

 The `eat()` method on `(some Animal)` expects `(some Animal).FeedType`,

 and not `(some Animal).FeedType.CropType.FeedType`.

 This program is not well-typed. These protocol definitions, as written, do not actually guarantee

 that if we start with a type of animal feed, and then grow and harvest this crop,

 we'll get back the same type of animal feed that we started with, which is what our animal expects to eat.

 Another way of think about it is that these protocol definitions are too general -

 they don't accurately model the desired relationship between our concrete types.

 To understad why, let's look at our `Hay` and `Alfalfa` types.

 ```
                   .CropType                 .FeedType                   .CropType
 [Hay: AnimalFeed] ────────► [Alfalfa: Crop] ────────► [Hay: AnimalFeed] ────────► [...]
 ```

 When I grow hay, I get alfalfa, and when I harvest alfalfa, I get hay, and so on.
*/

struct Cow_: Animal_ {
  var isHungry: Bool
  func eat(_ feed: Hay_) {}
}

struct Hay_: AnimalFeed_ {
  static func grow() -> Alfalfa_ { Alfalfa_() }
}

struct Alfalfa_: Crop_ {
  func harvest() -> Scratch_ { Scratch_() }
}

struct Scratch_: AnimalFeed_ {
  static func grow() -> Millet_ { Millet_() }
}

struct Millet_: Crop_ {
  func harvest() -> Scratch_ { Scratch_() }
}

/*:

 Now imagine I'm refactoring my code, and I accidentally change the return type of the `harvest()` method

 on `Alfalfa` to return `Scratch` instead of `Hay`. After this accidental change, the concrete types

 still satisfy the requirements even though we violate our desired invariant that growing and harvesting

 a crop produces the same type of animal feed that we started with.

 **The real problem here is that in a sense, we have too many distinct associated types.**

 We need to write down the fact that two of these associated types are actually the same concrete type.

 This will prevent incorrectly-written concrete types from conforming to our protocols,

 it will aslo to give the `feedAnimal()` method the guarantee that it needs.

 > We can express the relationship between these associated types using a same-type requirement,
 >
 > written in a `where` clause.
*/

protocol AnimalFeed__ {
  associatedtype CropType: Crop__ where CropType.FeedType == Self
  static func grow() -> CropType
}

/*:

 A same-type requirement expresses a static guarantee that two different, possibly nested associated types

 must in fact be the same conrete type.

 Adding a same-type requirement here imposes a restriction on the concrete types that conform

 to the `AnimalFeed` protocol.

 In this same-type requirement here, we're declaring that `Self.CropType.FeedType` is the same type as `Self`.

 ```
                    .CropType                       .FeedType
 [Self: AnimalFeed] ────────► [Self.CropType: Crop] ────────► [Self: AnimalFeed]
 ```

 Each conrete type conforming to `AnimalFeed` has a `CropType`, which conforms to `Crop`.

 However, the `FeedType` of this `CropType`, is not just some other type conforming to `AnimalFeed`,

 **it is the same concrete type as the original** `AnimalFeed`.

 Instead of an infinite tower of nested associated types,

 I've collapsed all relationships down to a single pair of related associated types.

 ```
                      .CropType
 ┌──────────────────┐ ────────► ┌─────────────────────┐
 │ Self: AnimalFeed │           │ Self.CropType: Crop │
 └──────────────────┘ ◄──────── └─────────────────────┘
                      .FeedType
 ```
*/

/*:
 The `Crop`'s `FeedType` has collapsed down to a pair of types, but we still have too many associated types.

 ```
                                                      .CropType
 ┌────────────┐.FeedType┌───────────────────────────┐ ────────► ┌──────────────────────────────┐
 │ Self: Crop │────────►│ Self.FeedType: AnimalFeed │           │ Self.FeedType.CropType: Crop │
 └────────────┘         └───────────────────────────┘ ◄──────── └──────────────────────────────┘
                                                      .FeedType
 ```

 We want to say that the `Crop`'s `FeedType`'s `CropType` is the same type as the `Crop` that we originally started with.
*/

protocol Crop__ {
  associatedtype FeedType: AnimalFeed__ where FeedType.CropType == Self
  func harvest() -> FeedType
}

/*:
 Now that these two protocols have been equipped with same-type requirements,

 we can revisit the `feedAnimal()` method again.
*/

extension Farm {
  private func feedAnimal__(_ animal: some Animal__) {
    // type(of: animal) -> some Animal: Animal
    // (some Animal).FeedType -> (some Animal).FeedType
    // grow() -> (some Animal).FeedType.CropType
    let crop = type(of: animal).FeedType.grow()
    // harvest() -> (some Animal).FeedType
    let feed = crop.harvest()
    // ✅ 🍽
    animal.eat(feed)
  }
}

protocol Animal__ {
  var isHungry: Bool { get }

  associatedtype FeedType: AnimalFeed__
  func eat(_: FeedType)
}

/*:
 ```

                                                .FeedType.grow()
 ┌─────────────┐.FeedType┌────────────────────────┐ ────────► ┌─────────────────────────────────┐
 │ some Animal │────────►│ (some Animal).FeedType │           │ (some Animal).FeedType.CropType │
 └─────────────┘         └────────────────────────┘ ◄──────── └─────────────────────────────────┘
                                                .CropType - harvest()
 ```

 We start with the type of `some Animal`, as before, and we get the `Animal`'s `FeedType`,

 which we know conforms to the `AnimalFeed` protocol.

 When we `grow()` this crop, we get `some Animal`'s `FeedType`'s `CropType`.

 But now, when we `harvest()` this crop, instead of getting yet another nested associated type,

 we get exactly the `FeedType` that our animal expects, and the happy animal is now guaranteed

 to `eat()` the correct type of `AnimalFeed` that we just grew.

 Finally, let's look at an associated type diagram for the `Animal` protocol,

 which pulls evertyhing together we've sees so far.

 ```
                                               .CropType
 ┌──────────────┐.FeedType┌──────────────────┐ ────────► ┌─────────────────────┐
 │ Self: Animal │────────►│ Self: AnimalFeed │           │ Self.CropType: Crop │
 └──────────────┘         └──────────────────┘ ◄──────── └─────────────────────┘
                                               .FeedType


                                                     .CropType
 ┌─────────────────┐.FeedType┌─────────────────────┐ ────────► ┌──────────────┐
 │ Chicken: Animal │────────►│ Scratch: AnimalFeed │           │ Millet: Crop │
 └─────────────────┘         └─────────────────────┘ ◄──────── └──────────────┘
                                                     .FeedType


                                             .CropType
 ┌─────────────┐.FeedType┌─────────────────┐ ────────► ┌───────────────┐
 │ Cow: Animal │────────►│ Hay: AnimalFeed │           │ Alfalfa: Crop │
 └─────────────┘         └─────────────────┘ ◄──────── └───────────────┘
                                             .FeedType
 ```

 Here are the two sets of conforming types:

 First, we have `Cow`, `Hay`, and `Alfalfa`.

 Second, we have `Chicken`, `Scratch` and `Millet`.

 Notice how our three protocols precisely model the relationships between each set of three concrete types.

 By understanding your data model, you can use same-type requirements to define equivalences between these

 different nested associated types. Generic code then rely on these relationships when chaining together

 multiple calls to protocol requirements.
*/
