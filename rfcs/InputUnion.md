RFC: GraphQL Input Union
----------

The addition of an Input Union type has been discussed in the GraphQL community for many years now. The value of this feature has largely been agreed upon, but the implementation has not.

This document attempts to bring together all the various solutions and perspectives that have been discussed with the goal of reaching a shared understanding of the problem space.

From that shared understanding, the GraphQL Working Group aims to reach a consensus on how to address the proposal.

Notes from the 2020/5/28 meeting: https://gist.github.com/leebyron/f7f9d81c7ca5259357fab5d82a4c0621

### Contributing

To help bring this idea to reality, you can contribute [PRs to this RFC document.](https://github.com/graphql/graphql-spec/edit/main/rfcs/InputUnion.md)

# 📜 Problem Statement

GraphQL currently provides polymorphic types that enable schema authors to model complex **Object** types that have multiple shapes while remaining type-safe, but lacks an equivilant capability for **Input** types.

Over the years there have been numerous proposals from the community to add a polymorphic input type. Without such a type, schema authors have resorted to a handful of work-arounds to model their domains. These work-arounds have led to schemas that aren't as expressive as they could be, and schemas where mutations that ideally mirror queries are forced to be modeled differently.

# 🐕 Problem Sketch

To understand the problem space a little more, we'll sketch out an example that explores a domain from the perspective of a Query and a Mutation. However, it's important to note that the problem is not limited to mutations, since `Input` types are used in field arguments for any GraphQL operation type.

Let's imagine an animal shelter for our example. When querying for a list of the animals, it's easy to see how abstract types are useful - we can get data specific to the type of the animal easily.

```graphql
{
  animalShelter(location: "Portland, OR") {
    animals {
      __typename
      name
      age
      ... on Cat { livesLeft }
      ... on Dog { breed }
      ... on Snake { venom }
    }
  }
}
```

However, when we want to submit data, we can't use an `interface` or `union`, so we must model around that.

One technique commonly used to is a **tagged union** pattern. This essentially boils down to a "wrapper" input that isolates each type into its own field. The field name takes on the convention of representing the type.

```graphql
mutation {
  logAnimalDropOff(
    location: "Portland, OR"
    animals: [
      {cat: {name: "Buster", age: 3, livesLeft: 7}}
    ]
  )
}
```

Unfortunately, this opens up a set of problems, since the Tagged union input type actually contains many fields, any of which could be submitted.

```graphql
input AnimalDropOffInput {
  cat: CatInput
  dog: DogInput
  snake: SnakeInput
}
```

This allows nonsensical mutations to pass GraphQL validation, for example representing an animal that is both a `Cat` and a `Dog`.

```graphql
mutation {
  logAnimalDropOff(
    location: "Portland, OR"
    animals: [
      {
        cat: {name: "Buster", age: 3, livesLeft: 7},
        dog: {name: "Ripple", age: 2, breed: WHIPPET}
      }
    ]
  )
}
```

In addition, relying on this layer of abstraction means that this domain must be modelled differently across input & output. This can put a larger burden on the developer interacting with the schema, both in terms of lines of code and complexity.

```json
// JSON structure returned from a query
{
  "animals": [
    {"__typename": "Cat", "name": "Ruby", "age": 2, "livesLeft": 9}
    {"__typename": "Snake", "name": "Monty", "age": 13, "venom": "POISON"}
  ]
}
```

```json
// JSON structure submitted to a mutation
{
  "animals": [
    {"cat": {"name": "Ruby", "age": 2, "livesLeft": 9}},
    {"snake": {"name": "Monty", "age": 13, "venom": "POISON"}}
  ]
}
```

Another approach is to use an input type with a discriminator and input fields for all possible member types.

```graphql
mutation {
  logAnimalDropOff(
    location: "Portland, OR"
    animals: [
      {type: CAT, name: "Buster", age: 3, livesLeft: 7},
      {type: DOG, name: "Ripple", age: 2, breed: WHIPPET}
    ]
  )
}

input AnimalDropOffInput {
  type: AnimalType!
  name: String!
  age: Int!
  breed: DogBreed # only applies when type = DOG
  livesLeft: Int # only applies when type = CAT
  venom: VenomType # only applies when type = SNAKE
}
```

This results in more consistent modeling between input & output but still allows nonsensical inputs to pass GraphQL validation.

Another common approach is to provide a unique mutation for every type. A schema employing this technique might have `logCatDropOff`, `logDogDropOff` and `logSnakeDropOff` mutations. This removes the potential for modeling non-sensical situations, but it explodes the number of mutations in a schema, making the schema less accessible. If the type is nested inside other inputs, this approach simply isn't feasable.

These workarounds only get worse at scale. Real world GraphQL schemas can have dozens if not hundreds of possible types for a single `Interface` or `Union`.

The goal of the **Input Union** is to bring a polymorphic type to Inputs. This would enable us to model situations where an input may be of different types in a type-safe and elegant manner, like we can with outputs.

```graphql
mutation {
  logAnimalDropOff(
    location: "Portland, OR"

    # Problem: we need to determine the type of each Animal
    animals: [
      # This is meant to be a CatInput
      {name: "Buster", age: 3, livesLeft: 7},

      # This is meant to be a DogInput
      {name: "Ripple", age: 2}
    ]
  )
}
```

In this mutation, we encounter the main challenge of the **Input Union** - we need to determine the correct type of the data submitted.

A wide variety of solutions have been explored by the community, and they are outlined in detail in this document under [Possible Solutions](#Possible-Solutions).


# 🎨 Prior Art

Many other technologies provide polymorphic types, and have done so using a variety of techniques.

Tech | Type | Read | Write
---- | -------- | ---- | -----
GraphQL | [Union](https://graphql.github.io/graphql-spec/June2018/#sec-Unions) | ✅ | ❌
Protocol Buffers | [Oneof](https://developers.google.com/protocol-buffers/docs/proto3#oneof) | ✅ | ✅
FlatBuffers | [Union](https://google.github.io/flatbuffers/flatbuffers_guide_writing_schema.html) | ✅ | ✅
Cap'n Proto | [Union](https://capnproto.org/language.html#unions) | ✅ | ✅
Thrift | [Union](https://thrift.apache.org/docs/idl#union) | ✅ | ✅
Arvo | [Union](https://avro.apache.org/docs/current/spec.html#Unions) | ✅ | ✅
OpenAPI 3 | [oneOf](https://swagger.io/docs/specification/data-models/oneof-anyof-allof-not/) | ✅ | ✅
JSON Schema | [oneOf](https://json-schema.org/understanding-json-schema/reference/combining.html#oneof) | ✅ | ✅
Typescript | [Union](http://www.typescriptlang.org/docs/handbook/advanced-types.html#union-types) | ✅ | ✅
Typescript | [Discriminated Union](http://www.typescriptlang.org/docs/handbook/advanced-types.html#discriminated-unions) | ✅ | ✅
Rust | [Enum](https://doc.rust-lang.org/rust-by-example/custom_types/enum.html) | ✅ | ✅
Swift | [Enumeration](https://docs.swift.org/swift-book/LanguageGuide/Enumerations.html) | ✅ | ✅
Haskell | [Algebraic data types](http://learnyouahaskell.com/making-our-own-types-and-typeclasses) | ✅ | ✅

The topic has also been extensively explored in Computer Science more generally.

* [Wikipedia: Algebraic data type](https://en.wikipedia.org/wiki/Algebraic_data_type)
* [Wikipedia: Union type](https://en.wikipedia.org/wiki/Union_type)
* [Wikipedia: Tagged Union](https://en.wikipedia.org/wiki/Tagged_union)
* [C2 Wiki: Nominative And Structural Typing](http://wiki.c2.com/?NominativeAndStructuralTyping)

There are also libraries that mimic this functionality in GraphQL:

* [graphql-union-input-type](https://github.com/Cardinal90/graphql-union-input-type)

# 🛠 Use Cases

There have been a variety of use cases described by users asking for an abstract input type.

* [Observability Metrics](https://github.com/graphql/graphql-spec/pull/395#issuecomment-489495267)
* [Login Options](https://github.com/graphql/graphql-js/issues/207#issuecomment-228543259)
* [Abstract Syntax Tree](https://github.com/graphql/graphql-spec/pull/395#issuecomment-489611199)
* [Content Widgets](https://github.com/graphql/graphql-js/issues/207#issuecomment-308344371)
* [Filtering](https://github.com/graphql/graphql-spec/issues/202#issue-170560819)
* [Observability Cloud Integrations](https://gist.github.com/binaryseed/f2dd63d1a1406124be70c17e2e796891#cloud-integrations)
* [Observability Dashboards](https://gist.github.com/binaryseed/f2dd63d1a1406124be70c17e2e796891#dashboards)

# 📋 Solution Criteria

This section sketches out the potential goals that a solution might attempt to fulfill. These goals will be evaluated with the [GraphQL Spec Guiding Principles](https://github.com/graphql/graphql-spec/blob/main/CONTRIBUTING.md#guiding-principles) in mind:

* Backwards compatibility
* Performance is a feature
* Favor no change
* Enable new capabilities motivated by real use cases
* Simplicity and consistency over expressiveness and terseness
* Preserve option value
* Understandability is just as important as correctness

Each criteria is identified with a `Letter` so they can be referenced in the rest of the document. New criteria must be added to the end of the list.

Solutions are evaluated and scored using a simple 3 part scale. A solution may have multiple evaluations based on variations present in the solution.

* ✅ **Pass.** The solution clearly meets the criteria
* ⚠️ **Warning.** The solution doesn't clearly meet or fail the criteria, or there is an important caveat to passing the criteria
* 🚫 **Fail.** The solution clearly fails the criteria
* ❔ The criteria hasn't been evaluated yet

Passing or failing a specific criteria is NOT the final word. Both the Criteria _and_ the Solutions are up for debate.

Criteria have been given a "score" according to their relative importance in solving the problem laid out in this RFC while adhering to the GraphQL Spec Guiding Principles. The scores are:

* 🥇 Gold - A must-have
* 🥈 Silver - A nice-to-have
* 🥉 Bronze - Not necessary

## 🎯 A. GraphQL should contain a polymorphic Input type

The premise of this RFC - GraphQL should contain a polymorphic Input type.

| [1][solution-1] | [2][solution-2] | [3][solution-3] | [4][solution-4] | [5][solution-5] | [6][solution-6] | [7][solution-7]
|----|----|----|----|----|----|----|
| ✅ | ✅ | ✅ | ✅ | ✅ | ❔ | ✅ |

Criteria score: 🥇

## 🎯 B. Input polymorphism matches output polymorphism

Any data structure that can be modeled with output type polymorphism should be able to be mirrored with Input polymorphism. Minimal transformation of outputs should be required to send a data structure back as inputs.

* ✂️ Objection: composite input types and composite output types are distinct. Fields on composite output types support aliases and arguments whereas fields on composite input types do not. Marking an output field as non-nullable is a non-breaking change, but marking an input field as non-nullable is a breaking change.

| [1][solution-1] | [2][solution-2] | [3][solution-3] | [4][solution-4] | [5][solution-5] | [6][solution-6] | [7][solution-7]
|----|----|----|----|----|----|----|
| ✅⚠️ | ✅ | ✅ | ✅⚠️ | 🚫 | ❔ | ✅⚠️ |

Criteria score: 🥇

## 🎯 C. Doesn't inhibit schema evolution

The GraphQL specification mentions the ability to evolve your schema as one of its core values:
https://graphql.github.io/graphql-spec/draft/#sec-Validation.Type-system-evolution

Adding a new member type to an Input Union or doing any non-breaking change to existing member types does not result in breaking change. For example, adding a new optional field to member type or changing a field from non-nullable to nullable does not break previously valid client operations.

| [1][solution-1] | [2][solution-2] | [3][solution-3] | [4][solution-4] | [5][solution-5] | [6][solution-6] | [7][solution-7]
|----|----|----|----|----|----|----|
| ✅ | ✅⚠️ | 🚫 | ⚠️ | ✅ | ❔ | ✅ |

Criteria score: 🥇

## 🎯 D. Any member type restrictions are validated in schema

If a solution places any restrictions on member types, compliance with these restrictions should be fully validated during schema building (analagous to how interfaces enforce restrictions on member types).

| [1][solution-1] | [2][solution-2] | [3][solution-3] | [4][solution-4] | [5][solution-5] | [6][solution-6] | [7][solution-7]
|----|----|----|----|----|----|----|
| ✅ | ✅ | ✅ | ✅ | ✅ | ❔ | ✅ |

Criteria score: 🥇

## 🎯 E. A member type may be a Leaf type

In addition to containing Input types, member type may also contain Leaf types like `Scalar`s or `Enum`s.

* ✂️ Objection: multiple Leaf types serialize the same way, making it impossible to distinguish the type without additional information. For example, a `String`, `ID` and `Enum`.
  * Potential solution: only allow a single built-in leaf type per input union.
* ✂️ Objection: Output polymorphism is restricted to Object types only. Supporting Leaf types in Input polymorphism would create a new inconsistency.

| [1][solution-1] | [2][solution-2] | [3][solution-3] | [4][solution-4] | [5][solution-5] | [6][solution-6] | [7][solution-7]
|----|----|----|----|----|----|----|
| 🚫 | 🚫 | ✅⚠️ | 🚫 | ✅ | ❔ | ✅ |

Criteria score: 🥉

## 🎯 F. Migrating a field to a polymorphic input type is non-breaking

Since the input object type is now a member of the input union, existing input objects being sent through should remain valid.

Example: Relay Mutation

```graphql
# From
input I { x: String }
# To (pseudocode)
input union IU = I | { y: Int }
```

* ✂️ Objection: achieving this by indicating the default in the union (either explicitly or implicitly via the order) is undesirable as it may require multiple equivalent unions being created where only the default differs.
* ✂️ Objection: Numerous changes to a schema currently introduce breaking changes. The possibility of a breaking change isn't a breaking change and shouldn't prevent a polymorphic input type from existing.

| [1][solution-1] | [2][solution-2] | [3][solution-3] | [4][solution-4] | [5][solution-5] | [6][solution-6] | [7][solution-7]
|----|----|----|----|----|----|----|
| ✅⚠️ | ✅⚠️ | ✅ | ⚠️ | 🚫 | ❔ | 🚫 |

Criteria score: 🥉

## 🎯 G. Input unions may include other input unions

To ease development.

* ✂️ Objection: Adds complexity without enabling any new use cases.

| [1][solution-1] | [2][solution-2] | [3][solution-3] | [4][solution-4] | [5][solution-5] | [6][solution-6] | [7][solution-7]
|----|----|----|----|----|----|----|
| ❔ | ❔ | ❔ | ❔ | ✅ | ❔ | ✅ |

Criteria score: X (not considered)

## 🎯 H. Input unions should accept plain data

Clients should be able to pass "natural" input data to unions without specially formatting it or adding extra metadata.

In other words: data should require minimal or no transformation and metadata over the wire

* ✂️ Objection: This is a matter of taste - legitimate [Prior Art](#-prior-art) exists that require formatting / extra metadata.

| [1][solution-1] | [2][solution-2] | [3][solution-3] | [4][solution-4] | [5][solution-5] | [6][solution-6] | [7][solution-7]
|----|----|----|----|----|----|----|
| ⚠️ | ⚠️ | ✅ | ✅ | ⚠️ | ❔ | ⚠️ |

Criteria score: 🥉

## 🎯 I. Input unions should be easy to upgrade from existing solutions

Many people in the wild are solving the need for input unions with validation at run-time (e.g. using the "tagged union" pattern). Formalising support for these existing patterns in a non-breaking way would enable existing schemas to become retroactively more type-safe.

Note: This criteria is similar to  [F. Migrating a field to a polymorphic input type is non-breaking][criteria-f]

```graphql
# From
input I { x: String, y: Int }
# To (pseudocode)
input union IU = { x: String } | { y: Int }
```

* ✂️ Objection: The addition of a polymorphic input type shouldn't depend on the ability to change the type of an existing field or an existing usage pattern. One can always add new fields that leverage new features.
* ✂️ Objection: May break variable names? Only avoided with care
* ✂️ Objection: There are different ways people are working around the lack of input unions so it likely won't be feasible to come up with a non-breaking migration path for all of them.

| [1][solution-1] | [2][solution-2] | [3][solution-3] | [4][solution-4] | [5][solution-5] | [6][solution-6] | [7][solution-7]
|----|----|----|----|----|----|----|
| ✅ | ✅ | ✅ | ⚠️ | ✅ | ❔ | ✅ |

Criteria score: 🥉

## 🎯 J. A GraphQL schema that supports input unions can be queried by older GraphQL clients

Preferably without a loss of or change in previously supported functionality.

| [1][solution-1] | [2][solution-2] | [3][solution-3] | [4][solution-4] | [5][solution-5] | [6][solution-6] | [7][solution-7]
|----|----|----|----|----|----|----|
| ✅ | ✅ | ✅ | ✅ | ✅ | ❔ | ✅ |

Criteria score: 🥇

## 🎯 K. Input unions should be expressed efficiently in the query and on the wire

The less typing and fewer bytes transmitted, the better.

(Not Related to B/H)

* ✂️ Objection: The quantity of "typing" isn't a worthwhile metric, most interactions with an API are programmatic.
* ✂️ Objection: Simply compressing an HTTP request will reduce the bytes transmitted more than anything having to do with the structure of a Schema.

| [1][solution-1] | [2][solution-2] | [3][solution-3] | [4][solution-4] | [5][solution-5] | [6][solution-6] | [7][solution-7]
|----|----|----|----|----|----|----|
| ✅ | ⚠️ | ✅ | ✅ | ✅ | ✅ | ✅ |

Criteria score: 🥉

## 🎯 L. Input unions should be performant for servers

Ideally a server does not have to do much computation to determine which concrete type is represented by an input.

| [1][solution-1] | [2][solution-2] | [3][solution-3] | [4][solution-4] | [5][solution-5] | [6][solution-6] | [7][solution-7]
|----|----|----|----|----|----|----|
| ✅ | ✅ | ⚠️ | ⚠️ | ✅ | ❔ | ✅ |

Criteria score: 🥉

## 🎯 M. Existing SDL parsers are backwards compatible with SDL additions

Common tools that parse GraphQL SDL should not fail when pointed at a schema which supports polymorphic input types.

* ✂️ Objection: Evolution of the SDL is expected with new features.
* ✂️ Objection: SDL syntax error can be a positive as a "fail fast" if a system doesn't know about input unions.

| [1][solution-1] | [2][solution-2] | [3][solution-3] | [4][solution-4] | [5][solution-5] | [6][solution-6] | [7][solution-7]
|----|----|----|----|----|----|----|
| 🚫 | 🚫 | 🚫 | 🚫 | ✅ | ❔ | 🚫 |

Criteria score: X (rejected)

## 🎯 N. Existing code generated tooling is backwards compatible with Introspection additions

For example, GraphiQL should successfully render when pointed at a schema which contains polymorphic input types. It should continue to function even if it can't support the polymorphic input type.

| [1][solution-1] | [2][solution-2] | [3][solution-3] | [4][solution-4] | [5][solution-5] | [6][solution-6] | [7][solution-7]
|----|----|----|----|----|----|----|
| ✅⚠️ | ✅⚠️ | ✅⚠️ | ✅⚠️ | ✅ | ❔ | ✅⚠️ |

Criteria score: 🥈

## 🎯 O. Unconstrained combination of input types to unions

It should be possible to combine existing or new input types to unions freely and with ease.
Adding an input to one or more unions should not require extraneous changes, constrain or be constrained by schema design.

| [1][solution-1] | [2][solution-2] | [3][solution-3] | [4][solution-4] | [5][solution-5] | [6][solution-6] | [7][solution-7]
|----|----|----|----|----|----|----|
| ✅️ | 🚫️ | ❔ | 🚫 | ✅ | ❔ | ✅ |

Criteria score: 🥇

## 🎯 P. Error states and messages should be clear and helpful

Complex algorithms can make it difficult to write error messages that are helpful and clear.
When an invalid schema or invalid query are used, it should be obvious what went wrong and how to fix it.

| [1][solution-1] | [2][solution-2] | [3][solution-3] | [4][solution-4] | [5][solution-5] | [6][solution-6] | [7][solution-7]
|----|----|----|----|----|----|----|
| ✅️ | ✅️ | ⚠️ | 🚫 | ✅ | ❔ | ✅ |

Criteria score: 🥉

## 🎯 Q. No new polymorphic type construct should be introduced

The lack of polymorphism on input is only a side-effect of having 2 different type systems for input and output, a somewhat confusing GraphQL specificity (all mainstream programming language and API protocol use the same types for input and output).
Adding a new construct for polymorphism support on input 'smells' like increasing confusion, and would increase the gap between input and output type systems, rather than reduce it.

| [1][solution-1] | [2][solution-2] | [3][solution-3] | [4][solution-4] | [5][solution-5] | [6][solution-6] | [7][solution-7]
|----|----|----|----|----|----|----|
| 🚫️ | 🚫️ | ✅ | 🚫️ | ✅ | ❔ | 🚫️ |

Criteria score: 🥇

# 🚧 Possible Solutions

The community has imagined a variety of possible solutions, synthesized here.

Each solution is identified with a `Number` so they can be referenced in the rest of the document. New solutions must be added to the end of the list.

## 💡 1. Explicit `__typename` Discriminator field

**Champion:** @eapache

This solution was discussed in https://github.com/graphql/graphql-spec/pull/395

```graphql
input CatInput {
  name: String!
  age: Int
  livesLeft: Int
}
input DogInput {
  name: String!
  age: Int
  breed: DogBreed
}

inputunion AnimalInput = CatInput | DogInput

type Mutation {
  logAnimalDropOff(location: String, animals: [AnimalInput!]!): Int
}

# Variables:
{
  location: "Portland, OR",
  animals: [
    {
      __typename: "CatInput",
      name: "Buster",
      livesLeft: 7
    }
  ]
}
```

### 🎲 Variations

* A `default` type may be defined, for which specifying the `__typename` is not required. This enables a field to migration from an `Input` to an `Input Union`

* The discriminator field may be `__inputname` to differentiate from an Output's `__typename`

### ⚖️ Evaluation

* [A. GraphQL should contain a polymorphic Input type][criteria-a]
  * ✅
* [B. Input polymorphism matches output polymorphism][criteria-b]
  * ✅ Data structures can mirror eachother.
  * ⚠️ `__typename` can not match since Input & Output types are distinct (ex: `Cat` vs `CatInput`).
* [C. Doesn't inhibit schema evolution][criteria-c]
  * ✅ Discriminator is explicit.
* [D. Any member type restrictions are validated in schema][criteria-d]
  * ✅ No member type restrictions
* [E. A member type may be a Leaf type][criteria-e]
  * 🚫 Requires a type to provide a discriminator field
* [F. Migrating a field to a polymorphic input type is non-breaking][criteria-f]
  * ⚠️ Discriminator field is required.
  * ✅ Defaulting to the previous input type enables migration.
* [H. Input unions should accept plain data][criteria-h]
  * ⚠️ One additional field is required.
* [I. Input unions should be easy to upgrade from existing solutions][criteria-i]
  * ✅ Defaulting to the previous input type enables upgrading
* [J. A GraphQL schema that supports input unions can be queried by older GraphQL clients][criteria-j]
  * ✅ Changes are additive only
* [K. Input unions should be expressed efficiently in the query and on the wire][criteria-k]
  * ✅ Discriminator field only needed when used in union
  * ✅ Compresses well, as the field name is always the same
* [L. Input unions should be performant for servers][criteria-l]
  * ✅ O(1)
* [M. Existing SDL parsers are backwards compatible with SDL additions][criteria-m]
  * 🚫 Parsers will not recognize the `inputunion` keyword
* [N. Existing code generated tooling is backwards compatible with Introspection additions][criteria-n]
  * ✅⚠️
* [O. Unconstrained combination of input types to unions][criteria-o]
  * ✅ Adding or removing an input type to a union has no extraneous effects on schema design
* [P. Error states and messages should be clear and helpful][criteria-p]
  * ✅
* [Q. No new polymorphic type construct should be introduced][criteria-q]
  * 🚫️ ``ìnputunion```is a new type construct

## 💡 2. Explicit configurable Discriminator field

**Champion:** @binaryseed

A configurable discriminator field enables schema authors to model type discrimination into their schema more naturally.

A schema author may choose to add their chosen type discriminator field to output types as well to completely mirror the structure in a way that enables sending data back and forth through input & output with no transformations.

The mechanism for configuring the discriminator field is open to debate, in this example it's represented with the use of a schema directive.

### 🎲 Variations

* Value is a `Enum` literal

This variation is derived from discussions in https://github.com/graphql/graphql-spec/issues/488

```graphql
enum AnimalSpecies {
  CAT
  DOG
}

input CatInput {
  species: AnimalSpecies::CAT
  # ...
}
input DogInput {
  species: AnimalSpecies::DOG
  # ...
}

inputunion AnimalInput @discriminator(field: "species") =
  | CatInput
  | DogInput

# Variables:
{
  location: "Portland, OR",
  animals: [
    {
      species: "CAT",
      name: "Buster",
      livesLeft: 7
    }
  ]
}
```

* Value is a `String` literal

```graphql
input CatInput {
  species: "Cat"
  # ...
}
input DogInput {
  species: "Dog"
  # ...
}

inputunion AnimalInput @discriminator(field: "species") =
  | CatInput
  | DogInput

# Variables:
{
  location: "Portland, OR",
  animals: [
    {
      species: "Cat",
      name: "Buster",
      livesLeft: 7
    }
  ]
}
```

### ⚖️ Evaluation

* [A. GraphQL should contain a polymorphic Input type][criteria-a]
  * ✅
* [B. Input polymorphism matches output polymorphism][criteria-b]
  * ✅ Data structures can mirror eachother.
* [C. Doesn't inhibit schema evolution][criteria-c]
  * ✅ Discriminator is explicit.
  * ⚠️ Adding an existing input type to an input union requires it to add the non-null discriminator field
* [D. Any member type restrictions are validated in schema][criteria-d]
  * ✅ Schema validation can check that all members of the input union have the discriminator field
* [E. A member type may be a Leaf type][criteria-e]
  * 🚫 Requires a type to provide a discriminator field
* [F. Migrating a field to a polymorphic input type is non-breaking][criteria-f]
  * ⚠️ Discriminator field is required.
  * ✅ Defaulting to the previous input type enables migration
* [H. Input unions should accept plain data][criteria-h]
  * ⚠️ One additional field is required.
* [I. Input unions should be easy to upgrade from existing solutions][criteria-i]
  * ✅ Defaulting to the previous input type enables upgrading
* [J. A GraphQL schema that supports input unions can be queried by older GraphQL clients][criteria-j]
  * ✅ Changes are additive only
* [K. Input unions should be expressed efficiently in the query and on the wire][criteria-k]
  * ⚠️ Input types that are part of an input union always have to contain the non-null discriminator
* [L. Input unions should be performant for servers][criteria-l]
  * ✅ O(1)
* [M. Existing SDL parsers are backwards compatible with SDL additions][criteria-m]
  * 🚫 Parsers will not recognize the `inputunion` keyword
* [N. Existing code generated tooling is backwards compatible with Introspection additions][criteria-n]
  * ✅⚠️
* [O. Unconstrained combination of input types to unions][criteria-o]
  * 🚫 Adding an input type to a union requires that it has the non-null discriminator field
     * The input might already have a field with the same name, but a different type
     * Reusing input types in multiple input unions can become unwieldy
* [P. Error states and messages should be clear and helpful][criteria-p]
  * ✅
* [Q. No new polymorphic type construct should be introduced][criteria-q]
  * 🚫️ ``ìnputunion```is a new type construct

## 💡 3. Order based discrimination

**Champion:** @leebyron

The concrete type is the first type in the input union definition that matches.

```graphql
input CatInput {
  name: String!
  age: Int
  livesLeft: Int
}
input DogInput {
  name: String!
  age: Int
  breed: DogBreed
  owner: ID
}

inputunion AnimalInput = CatInput | DogInput

type Mutation {
  logAnimalDropOff(location: String, animals: [AnimalInput!]!): Int
}

# Variables:
{
  location: "Portland, OR",
  animals: [
    {
      name: "Buster",
      age: 3
      # => CatInput
    },
    {
      name: "Buster",
      age: 3,
      breed: "WHIPPET"
      # => DogInput
    }
  ]
}
```

### ⚖️ Evaluation

* [A. GraphQL should contain a polymorphic Input type][criteria-a]
  * ✅
* [B. Input polymorphism matches output polymorphism][criteria-b]
  * ✅ Data structures can mirror eachother
* [C. Doesn't inhibit schema evolution][criteria-c]
  * 🚫 Adding a nullable field to an input object could change the detected type of fields or arguments in pre-existing operations.

    Using the example Schema, we can demonstrate this problem. Assume a mutation like this is being submitted:

    ```graphql
    mutation {
      logAnimalDropOff(
        location: "Portland, OR"
        animals: [{name: "Old Yeller", age: 10, owner: "Travis"}]
      )
    }
    ```

    Currently, order based type descrimination resolves to `DogInput`. However, if we modify `CatInput` to contain an `owner` field, type descrimination changes to `CatInput` even though the mutation submitted has not changed.
* [D. Any member type restrictions are validated in schema][criteria-d]
  * ✅ No member type restrictions
* [E. A member type may be a Leaf type][criteria-e]
  * ✅ Scalars could be listed in the inputunion and evaluated in order
  * ⚠️ Subject to subtle dangerous behavior. ie: `String` listed before an Enum could never match the Enum
* [F. Migrating a field to a polymorphic input type is non-breaking][criteria-f]
  * ✅ Listing the old input type first enables migration
* [H. Input unions should accept plain data][criteria-h]
  * ✅ No extra fields or structure required
* [I. Input unions should be easy to upgrade from existing solutions][criteria-i]
  * ✅ Listing the old input type first enables enables upgrading
* [J. A GraphQL schema that supports input unions can be queried by older GraphQL clients][criteria-j]
  * ✅ Changes are additive only
* [K. Input unions should be expressed efficiently in the query and on the wire][criteria-k]
  * ✅ No overhead
* [L. Input unions should be performant for servers][criteria-l]
  * ⚠️ O(N of members)
* [M. Existing SDL parsers are backwards compatible with SDL additions][criteria-m]
  * 🚫 Parsers will not recognize the `inputunion` keyword
* [N. Existing code generated tooling is backwards compatible with Introspection additions][criteria-n]
  * ✅⚠️
* [O. Unconstrained combination of input types to unions][criteria-o]
  * ❔ Not evaluated
* [P. Error states and messages should be clear and helpful][criteria-p]
  * ⚠️ Order-based discrimination can lead to some subtle issues based on when one type is chosen over another.
* [Q. No new polymorphic type construct should be introduced][criteria-q]
  * ✅ No new construct

## 💡 4. Structural uniqueness

Schema Rule: Each type in the union must have a unique set of required field names

```graphql
input CatInput {
  name: String!
  age: Int
  livesLeft: Int!
}
input DogInput {
  name: String!
  age: Int
  breed: DogBreed!
}

inputunion AnimalInput = CatInput | DogInput

type Mutation {
  logAnimalDropOff(location: String, animals: [AnimalInput!]!): Int
}

# Variables:
{
  location: "Portland, OR",
  animals: [
    {
      name: "Buster",
      age: 3,
      livesLeft: 7
      # => CatInput
    },
    {
      name: "Buster",
      breed: "WHIPPET"
      # => DogInput
    }
  ]
}
```

An invalid schema:

```graphql
input CatInput {
  name: String!
  age: Int!
  livesLeft: Int
}
input DogInput {
  name: String!
  age: Int!
  breed: DogBreed
}
```

### 🎲 Variations

* Consider the field _type_ along with the field _name_ when determining uniqueness.

### ⚖️ Evaluation

* [A. GraphQL should contain a polymorphic Input type][criteria-a]
  * ✅
* [B. Input polymorphism matches output polymorphism][criteria-b]
  * ✅ Data structures can mirror eachother's fields
  * ⚠️ Restrictions on required fields may prevent matching output types
* [C. Doesn't inhibit schema evolution][criteria-c]
  * ⚠️ Inputs may be forced to include extraneous fields to ensure uniqueness.
  * ⚠️ Making a field nullable may be impossible without losing uniqueness
* [D. Any member type restrictions are validated in schema][criteria-d]
  * ✅ A "uniqueness" algorithm must be applied during schema validation
* [E. A member type may be a Leaf type][criteria-e]
  * 🚫 Ambiguous types unable to be discriminated. ex: `String` vs `Enum` vs `ID`
* [F. Migrating a field to a polymorphic input type is non-breaking][criteria-f]
  * ⚠️ All new types added to the union must differ structurally from the previous type
* [H. Input unions should accept plain data][criteria-h]
  * ✅ No extra fields or structure required
* [I. Input unions should be easy to upgrade from existing solutions][criteria-i]
  * ⚠️ All new types added to the union must differ structurally from the previous type
* [J. A GraphQL schema that supports input unions can be queried by older GraphQL clients][criteria-j]
  * ✅ Changes are additive only
* [K. Input unions should be expressed efficiently in the query and on the wire][criteria-k]
  * ✅ No overhead
* [L. Input unions should be performant for servers][criteria-l]
  * ⚠️ O(N of members)
* [M. Existing SDL parsers are backwards compatible with SDL additions][criteria-m]
  * 🚫 Parsers will not recognize the `inputunion` keyword
* [N. Existing code generated tooling is backwards compatible with Introspection additions][criteria-n]
  * ✅⚠️
* [O. Unconstrained combination of input types to unions][criteria-o]
  * 🚫 Input types with similar fields may not be able to be combined without breaking changes
* [P. Error states and messages should be clear and helpful][criteria-p]
  * 🚫 Structural uniqueness checks are very complex and have many hard-to-describe failure states.
* [Q. No new polymorphic type construct should be introduced][criteria-q]
  * 🚫️ ``ìnputunion```is a new type construct

## 💡 5. One Of (Tagged Union)

**Champion:** @benjie

This solution was presented in:
* https://github.com/graphql/graphql-spec/pull/395#issuecomment-361373097
* https://github.com/graphql/graphql-spec/pull/586

The type is discriminated using features already available in GraphQL, with an intermediate input type that acts to "tag" the field.

A proposed directive would specify that only one of the fields in an input type may be provided. This provides schema-level validation instead of relying on a runtime error to express the restriction.

```graphql
input CatInput {
  name: String!
  age: Int!
  livesLeft: Int
}
input DogInput {
  name: String!
  age: Int!
  breed: DogBreed
}

input AnimalInput @oneOf {
  cat: CatInput
  dog: DogInput
}

type Mutation {
  logAnimalDropOff(location: String, animals: [AnimalInput!]!): Int
}

# Variables:
{
  location: "Portland, OR",
  animals: [
    {
      cat: {
        name: "Buster",
        livesLeft: 7
      }
    }
  ]
}
```

### ⚖️ Evaluation

* [A. GraphQL should contain a polymorphic Input type][criteria-a]
  * ✅ Tagged union is a valid version of a polymorphic type
* [B. Input polymorphism matches output polymorphism][criteria-b]
  * 🚫 The shape of the input type is forced to have a different structure than the corresponding output type.
* [C. Doesn't inhibit schema evolution][criteria-c]
  * ✅ This technique is already in use in many schemas with the extra validation
* [D. Any member type restrictions are validated in schema][criteria-d]
  * ✅ No schema changes, only an additional client side validation is added
* [E. A member type may be a Leaf type][criteria-e]
  * ✅ Any GraphQL type may be used
* [F. Migrating a field to a polymorphic input type is non-breaking][criteria-f]
  * 🚫 Previously-valid inputs now need to be wrapped in a container object
* [G. Input unions may include other input unions][criteria-g]
  * ✅ Any GraphQL type may be used, including other tagged types and wrapper types such as list
* [H. Input unions should accept plain data][criteria-h]
  * ⚠️ The data is wrapped in a (simple) container type
* [I. Input unions should be easy to upgrade from existing solutions][criteria-i]
  * ✅ No migration required, as this pattern is already possible
* [J. A GraphQL schema that supports input unions can be queried by older GraphQL clients][criteria-j]
  * ✅ Changes are additive only
* [K. Input unions should be expressed efficiently in the query and on the wire][criteria-k]
  * ✅ Indication of the type can be done in 6 additional JSON characters per value (e.g. `{"a":VALUE_HERE}`) and would compress easily.
* [L. Input unions should be performant for servers][criteria-l]
  * ✅ Type is easily determined by looking up the specified field name
* [M. Existing SDL parsers are backwards compatible with SDL additions][criteria-m]
  * ✅ Proposal uses a simple directive; directive parsing is widely supported
* [N. Existing code generated tooling is backwards compatible with Introspection additions][criteria-n]
  * ✅ Existing code generation tools will degrade gracefully to a regular input object
* [O. Unconstrained combination of input types to unions][criteria-o]
  * ✅ Adding or removing input types to a tagged union requires no extraneous effort
* [P. Error states and messages should be clear and helpful][criteria-p]
  * ✅
* [Q. No new polymorphic type construct should be introduced][criteria-q]
  * ✅

### Summary of spec changes

- **SDL**: enable use of `@oneOf` directive on input object type definitions
- **Introspection**: add `requiresExactlyOneField: Boolean` field to `__Type` type
- **Schema validation**: all fields on a `@oneOf` input type must be nullable, and must not have defaults
- **Operation validation**: when validating a `@oneOf` input object, assert that exactly one field was specified

[The full spec changes can be seen here](https://github.com/graphql/graphql-spec/pull/586/files).

## 💡 6. Pending

Calls within the Input Union working group proposed a new solution, solution 6,
which is a combination of features from solutions 1-4. It has not been fully
formalized yet as the working group felt that the Tagged Type was more
promising at this stage. This section is left as a placeholder for solution 6
to be formally evaluated at a later time.

For some of the notes we took during the calls, see:
https://github.com/graphql/graphql-wg/issues/426#issuecomment-685636596

For the calls themselves, see:
https://www.youtube.com/watch?v=u2dnnpKEHZM&list=PLP1igyLx8foH4M0YAbVqpSo2fS1ElvNVD

## 💡 7. Tagged Type

**Champion:** @benjie

This solution was presented in:

* https://github.com/graphql/graphql-spec/pull/733

It's the spiritual successor of [Solution 5 - the @oneOf
directive](#solution-5) after extensive feedback from the Input Unions working
group.

In this solution, a new type is introduced to the GraphQL type system: the
tagged type. The tagged type has two forms: a `tagged input` (valid only in
inputs) and a `tagged output` (valid only in outputs), but the definitions look
identical otherwise.

These tagged types define a list of member fields, exactly one of which must be
present.

```graphql
input CatInput {
  name: String!
  age: Int!
  livesLeft: Int
}
input DogInput {
  name: String!
  age: Int!
  breed: DogBreed
}

tagged input AnimalInput {
  cat: CatInput!
  dog: DogInput!
}

type Mutation {
  logAnimalDropOff(location: String, animals: [AnimalInput!]!): Int
}

# Variables:
{
  location: "Portland, OR",
  animals: [
    {
      cat: {
        name: "Buster",
        livesLeft: 7
      }
    }
  ]
}
```

There's controversy over whether the `tagged output` should be introduced or
not, more details on this can be read in
https://github.com/graphql/graphql-spec/pull/733

### ⚖️ Evaluation

* [A. GraphQL should contain a polymorphic Input type][criteria-a]
  * ✅ Tagged is a valid version of a polymorphic type
* [B. Input polymorphism matches output polymorphism][criteria-b]
  * ✅ When `tagged input` and `tagged output` are both included into the
    spec, a `tagged output` can have a mirrored `tagged input` in a similar way
    that a `type` can have a mirrored `input`
  * ⚠️ There's controversy over whether `tagged output` should be included in
    the spec as it causes confusion as to when to use union, interface, or
    tagged
* [C. Doesn't inhibit schema evolution][criteria-c]
  * ✅ This technique is an evolution of a technique already in use in many schemas
* [D. Any member type restrictions are validated in schema][criteria-d]
  * ✅ Tagged member fields are well defined
* [E. A member type may be a Leaf type][criteria-e]
  * ✅ Any GraphQL type may be used, including other tagged types and wrapper types such as list
* [F. Migrating a field to a polymorphic input type is non-breaking][criteria-f]
  * 🚫 Previously-valid inputs now need to be wrapped in a container object
* [G. Input unions may include other input unions][criteria-g]
  * ✅ Any GraphQL type may be used, including other tagged types and wrapper types such as list
* [H. Input unions should accept plain data][criteria-h]
  * ⚠️ The data is wrapped in a (simple) container type
* [I. Input unions should be easy to upgrade from existing solutions][criteria-i]
  * ✅ This pattern is already possible, existing tagged inputs can be converted to Tagged type
* [J. A GraphQL schema that supports input unions can be queried by older GraphQL clients][criteria-j]
  * ✅ Changes are additive only
* [K. Input unions should be expressed efficiently in the query and on the wire][criteria-k]
  * ✅ Indication of the type can be done in 6 additional JSON characters per value (e.g. `{"a":VALUE_HERE}`) and would compress easily.
* [L. Input unions should be performant for servers][criteria-l]
  * ✅ Type is easily determined by looking up the specified field name
* [M. Existing SDL parsers are backwards compatible with SDL additions][criteria-m]
  * 🚫 New keywords are introduced
* [N. Existing code generated tooling is backwards compatible with Introspection additions][criteria-n]
  * ✅⚠️
* [O. Unconstrained combination of input types to unions][criteria-o]
  * ✅ Adding or removing member fields to a tagged type requires no extraneous effort and has no non-local consequences
* [P. Error states and messages should be clear and helpful][criteria-p]
  * ✅
* [Q. No new polymorphic type construct should be introduced][criteria-q]
  * 🚫️ ``tagged```is a new type construct

### Summary of spec changes

- **SDL**: introduce new `tagged input` and `tagged output` definitions,
  including member fields
- **Introspection**: add new type and `__Type.memberFields` field to relate to
  these fields, and `__Type.isInputType`/`__Type.isOutputType` fields to
  differentiate input versus output tagged types
- **Schema validation**: tagged types must contain only types that are
  compatible (matching input or output) and must contain at least one field
- **Operation validation**: when validating a tagged input type, assert that
  exactly one field was specified

[The full spec changes can be seen here](https://github.com/graphql/graphql-spec/pull/733/files).

# 🏆 Evaluation Overview

A quick glance at the evaluation results. Remember that passing or failing a specific criteria is NOT the final word.

|    | [1][solution-1] | [2][solution-2] | [3][solution-3] | [4][solution-4] | [5][solution-5] | [6][solution-6] | [7][solution-7] |
| -- | -- | -- | -- | -- | -- | -- | -- |
| [A][criteria-a] 🥇 | ✅ | ✅ | ✅ | ✅ | ✅ | ? | ✅ |
| [B][criteria-b] 🥇 | ✅⚠️ | ✅ | ✅ | ✅⚠️ | 🚫 | ? | ✅⚠️ |
| [C][criteria-c] 🥇 | ✅ | ✅⚠️ | 🚫 | ⚠️ | ✅ | ? | ✅ |
| [D][criteria-d] 🥇 | ✅ | ✅ | ✅ | ✅ | ✅ | ? | ✅ |
| [E][criteria-e] 🥉 | 🚫 | 🚫 | ✅⚠️ | 🚫 | ✅ | ? | ✅ |
| [F][criteria-f] 🥉 | ✅⚠️ | ✅⚠️ | ✅ | ⚠️ | 🚫 | ? | 🚫 |
| [G][criteria-g] 🥉 | ❔ | ❔ | ❔ | ❔ | ❔ | ? | ✅ |
| [H][criteria-h] 🥉 | ⚠️ | ⚠️ | ✅ | ✅ | ⚠️ | ? | ⚠️ |
| [I][criteria-i] 🥉 | ✅ | ✅ | ✅ | ⚠️ | ✅ | ? | ✅ |
| [J][criteria-j] 🥇 | ✅ | ✅ | ✅ | ✅ | ✅ | ? | ✅ |
| [K][criteria-k] 🥉 | ✅ | ⚠️ | ✅ | ✅ | ✅ | ? | ✅ |
| [L][criteria-l] 🥉 | ✅ | ✅ | ⚠️ | ⚠️ | ✅ | ? | ✅ |
| [M][criteria-m] 🥈 | 🚫 | 🚫 | 🚫 | 🚫 | ✅ | ? | 🚫 |
| [N][criteria-n] 🥈 | ✅⚠️ | ✅⚠️ | ✅⚠️ | ✅⚠️ | ✅ | ? | ✅⚠️ |
| [O][criteria-o] 🥈 | ✅️ | 🚫️ | ❔ | 🚫 | ✅ | ? | ✅ |
| [P][criteria-p] 🥉 | ✅️ | ✅️ | ⚠️ | 🚫 | ✅ | ❔ | ✅ |
| [Q][criteria-q] 🥉 | 🚫 | 🚫 | ✅️ | 🚫 | ✅ | ❔ | 🚫 |

[criteria-a]: #-a-graphql-should-contain-a-polymorphic-input-type
[criteria-b]: #-b-input-polymorphism-matches-output-polymorphism
[criteria-c]: #-c-doesnt-inhibit-schema-evolution
[criteria-d]: #-d-any-member-type-restrictions-are-validated-in-schema
[criteria-e]: #-e-a-member-type-may-be-a-leaf-type
[criteria-f]: #-f-migrating-a-field-to-a-polymorphic-input-type-is-non-breaking
[criteria-g]: #-g-input-unions-may-include-other-input-unions
[criteria-h]: #-h-input-unions-should-accept-plain-data
[criteria-i]: #-i-input-unions-should-be-easy-to-upgrade-from-existing-solutions
[criteria-j]: #-j-a-graphql-schema-that-supports-input-unions-can-be-queried-by-older-graphql-clients
[criteria-k]: #-k-input-unions-should-be-expressed-efficiently-in-the-query-and-on-the-wire
[criteria-l]: #-l-input-unions-should-be-performant-for-servers
[criteria-m]: #-m-existing-sdl-parsers-are-backwards-compatible-with-sdl-additions
[criteria-n]: #-n-existing-code-generated-tooling-is-backwards-compatible-with-introspection-additions
[criteria-o]: #-o-unconstrained-combination-of-input-types-to-unions
[criteria-p]: #-p-error-states-and-messages-should-be-clear-and-helpful
[criteria-q]: #-q-no-new-polymorphic-type-construct-should-be-introduced

[solution-1]: #-1-explicit-__typename-discriminator-field
[solution-2]: #-2-explicit-configurable-discriminator-field
[solution-3]: #-3-order-based-discrimination
[solution-4]: #-4-structural-uniqueness
[solution-5]: #-5-one-of-tagged-union
[solution-6]: #-6-pending
[solution-7]: #-7-tagged-type

# ☑️ Decision Time!

Following meetings of the GraphQL Input Unions working group, [Solution 7][solution-7] was
proposed as an evolution of Solution 5, and is currently the leading solution.

~~According to a simple [weight ranking](https://docs.google.com/spreadsheets/d/1ymKqI6BSTHGGHkf9IDjo0EJmOqMryS-uQRwDV77OF5g/edit?usp=sharing), here are the solutions in order:~~

* ~~[5][solution-5]~~
* ~~[1][solution-1]~~
* ~~[2][solution-2]~~
* ~~[3][solution-3] / [4][solution-4]~~

