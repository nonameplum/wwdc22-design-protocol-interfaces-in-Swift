//: [Previous](@previous)

import Foundation

/*:
 # Understand type erasure

 ## Associated type

 By using an associated type, we're declaing that, given some concrete type of `Animal`,

 calling `produce()` returns some specific type of Food, that depends on the concrete `Animal` type.

 ```
                .CommodityType
 [Self: Animal] ─────────────► [Self.CommodityType: Food]
 ```

 The protocol `Self` type stands in for the actual concrete type conforming to the `Animal` protocol.

 The `Self` type has an associated `Commodity` type, conforming to `Food`.
*/
protocol Animal {
  associatedtype CommodityType: Food

  func produce() -> CommodityType
}

/*:

 ```
                   .CommodityType
 [Chicken: Animal] ─────────────► [Egg: Food]
 ```

 The `Chicken` type conforms to the `Animal` protocol with a `CommodityType` of `Egg`.
*/

struct Chicken: Animal {
  func produce() -> Egg { Egg() }
}

/*:

 ```
               .CommodityType
 [Cow: Animal] ─────────────► [Milk: Food]
 ```

 The `Cow` type conforms to the `Animal` protocol with a `CommodityType` of `Milk`.
 */

struct Cow: Animal {
  func produce() -> Milk { Milk() }
}

protocol Food {}

struct Egg: Food {}

struct Milk: Food {}

/*:

 The `animals` stored property on `Farm` is a heterogenous array of `any Animal`.

 `any Animal` type has a box representation that has the ability to store any concrete type of animal dynamically.

 This strategy of using the same representation for different concrete types is called type erasure.

 The box represents the existential type.

 ```
 ┌──────┐  ┌─────┐
 │  🐔  │  │  │  │
 └──────┘  └──│──┘
              ▼
              🐮
 ```

 */
struct Farm {
  var animals: [any Animal]

  func produceCommodities() -> [any Food] {
    return animals.map { animal in
      animal.produce()
      // ▲
      // │
      // The `animal` parameter in the `map()` closure has type `any Animal`.
      // The return type of `produce()` is an associated type.
    }
  }
}

/*:
 When you call a method returning an associated type on an existential type,

 the compiler will use type erasure to determine the result type for the call.

 ```
                .CommodityType
 [Self: Animal] ─────────────► [Self.CommodityType: Food]
 ```

 Type erasure replaces these associated types with corresponding existential types

 that have equivalent constraints.

 ```
              .CommodityType
 [any Animal] ─────────────► [any Food]
 ```

 We've erased the relationship between the concrete `Animal` type

 and the associated `CommodityType` by replacing them with `any Animal` and `any Food`.

 ```
 associatedtype CommodityType: Food
 ```

 The type `any Food` is called the **upper bound** of the associated `CommodityType`.

 Since the `produce()` method is called on an `any Animal`, the return value is type erased,

 giving us a value of type `any Food`.
*/

/*:
 ## Type erasure semnatics

 Associated types appearing in the **result** of a function declaration are in the **producing position**.

 Because calling the method will produce a value of this type.

 When we call this method on `any Animal`

 ```
  ┌──────┐
  │  🐮  │
  └──────┘
 any Animal
 ```

 we don't know the concrete result type at compile time, but we do know that it is a subtype of the upper bound.
*/

let animals: [any Animal] = [Cow()]

animals.map { animal in
  animal.produce()
}

/*:
 Here in this example, we'are calling `produce()` on an `any Animal` that holds a `Cow` at runtime.

 In our case, the `produce()` method on `Cow` returns `Milk`.

 ```
  ┌──────┐           ┌──────┐
  │  🐮  │ ────────► │  🥛  │
  └──────┘           └──────┘
 any Animal          any Food
 ```

 `Milk` can be stored inside of an `any Food`, which is the upper bound of the associated

 `CommodityType` of the `Animal` protocol.

 This is always safe, for all concrete types that conform to the `Animal` protocol.
*/

/*:
 Associated types appearing in the **parameter list** of a function declaration are in **consuming position**.
*/

protocol Animal_ {
  associatedtype FeedType: AnimalFeed

  func eat(_: FeedType)
}

struct Cow_: Animal_ {
  func eat(_ feed: Hay) {}
}

protocol AnimalFeed {}

struct Hay: AnimalFeed {}

struct Alfalfa: AnimalFeed {}

/*:
 Here the `eat()` method on the `Animal` protocol has the associated `FeedType` in consuming position.

 We need to pass in a value of this type a call the method.
*/


do {
  let animals: [any Animal_] = [Cow_()]

  animals.map { animal in
//    animal.eat(???) // We cannot pass e.g. `Hay()`
  }
}

/*:
 Since the conversion goes in the other direction, type erasure cannot be performed.

 The upper bound existential type (`AnimalFeed`) for the associated type (`FeedType`)

 does **not** safety convert to the actual concrete type, because the concrete type is unknown.

 ```
    ┌──────┐           ┌──────┐
    │  🌾  │ ────────► │  🐮  │
    └──────┘           └──────┘
 any AnimalFeed       any Animal
 ```

 We have an `any Animal` sotring a `Cow`. Suppuse that the `eat` method on `Cow` takes `Hay`.

 The upper bound of the `Animal` protocol's associated `FeedType` is `any AnimalFeed`.

 But given an arbitrary `any AnimalFeed`, there is no way to statically guarantee that it stores
 the `Hay` concrete type.
*/

/*:
 > Type erasure does not allow us to work with associated types in consuming position.
 >
 > Instead, you must unbox the existential `any` type by passing
 > it to a function that takes an opaque `some` type.
*/

/*:
 ## Type erasure with `Self` result type

 Exiting behaviour with protocol requirements returning `Self`.
*/

protocol Cloneable: AnyObject {
  func clone() -> Self
}

/*:
 This protocol defines a single `clone()` method, returning `Self`.
*/

class Human: Cloneable {
  func clone() -> Self {
    return self
  }
}

let object: any Cloneable = Human()
let cloned = object.clone()

/*:
 When you call `clone()` on a value of type `any Cloneable`, the result type `Self`, is type erased

 to its upper bound. The upper bound of the `Self` type is always the protocol itself, so we get

 back a new value of type `any Cloneable`.

 ```
             .clone()
    ┌──────┐           ┌──────┐
    │      │ ────────► │      │
    └──────┘           └──────┘
 any Cloneable       any Cloneable
 ```
*/

/*:
 ## Type erasure recap

 * `any` now supports protocols with associated types

   You can use `any` to declare that the type of a value is an existential type

   that stores some concrete type conforming to a protocol.

   This even works with protocols that have associated types.

 * Associated types in **producing** position are type erased to their upper bound

   When calling a protocol method with an associated type in producing position,

   the associated type is type-erased to its upper bound, which is another

   existential type that carries the associated type's constraints.
*/

//: [Next](@next)
