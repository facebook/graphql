RFC: GraphQL Input Union
----------

The addition of an Input Union type has been discussed in the GraphQL community for many years now. The value of this feature has largely been agreed upon, but the implementation has not.

This document attempts to bring together all the various solutions and perspectives that have been discussed with the goal of reaching a shared understanding of the problem space.

From that shared understanding, the GraphQL Working Group aims to reach a consensus on how to address the proposal.

### Contributing

To help bring this idea to reality, you can contribute [PRs to this RFC document.](https://github.com/graphql/graphql-spec/edit/master/rfcs/InputUnion.md)

## Problem Statement

GraphQL currently provides polymorphic types that enable schema authors to model complex **Object** types that have multiple shapes while remaining type-safe, but lacks an equivilant capability for **Input** types.

Over the years there have been numerous proposals from the community to add a polymorphic input type. Without such a type, schema authors have resorted to a handful of work-arounds to model their domains. These work-arounds have led to schemas that aren't as expressive as they could be, and schemas where mutations that ideally mirror queries are forced to be modeled differently.

## Problem Sketch

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

One technique commonly used to is a **tagged union** pattern. This essentially boils down to a "wrapper" input that isolates each type into it's own field. The field name takes on the convention of representing the type.

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

This allows non-sensical mutations to pass GraphQL validation, for example representing an animal that is both a `Cat` and a `Dog`.

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


## Prior Art

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


## Solution Criteria

This section sketches out the potential goals that a solution might attempt to fulfill. These goals will be evaluated with the [GraphQL Spec Guiding Principles](https://github.com/graphql/graphql-spec/blob/master/CONTRIBUTING.md#guiding-principles) in mind:

* Backwards compatibility
* Performance is a feature
* Favor no change
* Enable new capabilities motivated by real use cases
* Simplicity and consistency over expressiveness and terseness
* Preserve option value
* Understandability is just as important as correctness

Each criteria is identified with a Letter so they can be referenced in the rest of the document. New criteria must be added to the end of the list.

### A) GraphQL should contain a polymorphic Input type

The premise of this RFC - GraphQL should contain a polymorphic Input type.

### B) Input polymorphism matches output polymorphism

Any data structure that can be modeled with output type polymorphism should be able to be mirrored with Input polymorphism. Minimal transformation of outputs should be required to send a data structure back as inputs.

* Objection: composite input types and composite output types are distinct. Fields on composite output types support aliases and arguments whereas fields on composite input types do not. Marking an output field as non-nullable is a non-breaking change, but marking an input field as non-nullable is a breaking change.

### C) Doesn't inhibit schema evolution

The GraphQL specification mentions the ability to evolve your schema as one of its core values:
https://graphql.github.io/graphql-spec/draft/#sec-Validation.Type-system-evolution

Adding a new member type to an Input Union or doing any non-breaking change to existing member types does not result in breaking change. For example, adding a new optional field to member type or changing a field from non-nullable to nullable does not break previously valid client operations.

### D) Any member type restrictions are validated in schema

If a solution places any restrictions on member types, compliance with these restrictions should be fully validated during schema building (analagous to how interfaces enforce restrictions on member types).

### E) A member type may be a Leaf type

In addition to containing Input types, member type may also contain Leaf types like `Scalar`s or `Enum`s.

* Objection: multiple Leaf types serialize the same way, making it impossible to distinguish the type without additional information. For example, a `String`, `ID` and `Enum`.
  * Potential solution: only allow a single built-in leaf type per input union.
* Objection: Output polymorphism is restricted to Object types only. Supporting Leaf types in Input polymorphism would create a new inconsistency.

### F) Changing field from an input type to a polymorphic type including that type is non-breaking

Since the input object type is now a member of the input union, existing input objects being sent through should remain valid.

* Objection: achieving this by indicating the default in the union (either explicitly or implicitly via the order) is undesirable as it may require multiple equivalent unions being created where only the default differs.
* Objection: achieving this by indicating a default type in the input field is verbose/potentially ugly.

### G) Input unions may include other input unions

To ease development.

### H) Input unions should accept plain data from clients

Clients should be able to pass "natural" input data to unions without
specially formatting it, adding extra metadata, or otherwise doing work.

### I) Input unions should be easy to upgrade from existing solutions

Many people in the wild are solving the need for input unions with validation at run-time (e.g. using the "tagged union" pattern). Formalising support for these existing patterns in a non-breaking way would enable existing schemas to become retroactively more type-safe.

### J) A GraphQL schema that supports input unions can be queried by older GraphQL clients

Preferably without loss of functionality.

### K) Input unions should be expressed efficiently in the query and on the wire

The less typing and fewer bytes transmitted, the better.

### L) Input unions should be performant for servers

Ideally a server does not have to do much computation to determine which concrete type is represented by an input.

## Use Cases

There have been a variety of use cases described by users asking for an abstract input type.

* [Observability Metrics](https://github.com/graphql/graphql-spec/pull/395#issuecomment-489495267)
* [Login Options](https://github.com/graphql/graphql-js/issues/207#issuecomment-228543259)
* [Abstract Syntax Tree](https://github.com/graphql/graphql-spec/pull/395#issuecomment-489611199)
* [Content Widgets](https://github.com/graphql/graphql-js/issues/207#issuecomment-308344371)
* [Filtering](https://github.com/graphql/graphql-spec/issues/202#issue-170560819)
* [Observability Cloud Integrations](https://gist.github.com/binaryseed/f2dd63d1a1406124be70c17e2e796891#cloud-integrations)
* [Observability Dashboards](https://gist.github.com/binaryseed/f2dd63d1a1406124be70c17e2e796891#dashboards)


## Possible Solutions

Each of the solutions should be evaluated against each of the criteria.

To get an overview, the following table broadly rates how good the solution fulfils
a certain criteria. Positive is always *good*, so if a criteria is something bad and
the solution does avoid the negative aspact, it gets a o
- `o` Positive
- `-` Neutral/Not applicable
- `x` Negative

|   | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|
| A |   |   |   |   |   |
| B |   |   |   |   | x |
| C |   |   | x | x |   |
| D |   |   |   |   |   |
| E |   |   |   |   |   |
| F |   |   |   |   |   |
| G |   |   |   |   |   |
| H | x | x |   |   |   |
| I |   |   |   |   |   |
| J |   |   |   |   |   |
| K |   |   |   |   |   |
| L | x | x |   |   |   |

More detailed evaluations are to be placed in each solution's description.

### 1. Single `__typename` field; value is the `type`

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

#### Variations:

* A `default` type may be defined, for which specifying the `__typename` is not required. This enables a field to migration from an `Input` to an `Input Union`

#### Evaluation

##### [GraphQL should contain a polymorphic Input type](#a-graphql-should-contain-a-polymorphic-input-type)

##### [Input polymorphism matches output polymorphism](#b-input-polymorphism-matches-output-polymorphism)

##### [Doesn't inhibit schema evolution](#c-doesnt-inhibit-schema-evolution)

##### [Any member type restrictions are validated in schema](#d-any-member-type-restrictions-are-validated-in-schema)

##### [A member type may be a Leaf type](#e-a-member-type-may-be-a-leaf-type)

##### [Changing field from an input type to a polymorphic type including that type is non-breaking](#f-changing-field-from-an-input-type-to-a-polymorphic-type-including-that-type-is-non-breaking)

##### [Input unions may include other input unions](#g-input-unions-may-include-other-input-unions)

##### [Input unions should accept plain data from clients](#h-input-unions-should-accept-plain-data-from-clients)

No, as there is an additional field that has to be added.

##### [Input unions should be easy to upgrade from existing solutions](#i-input-unions-should-be-easy-to-upgrade-from-existing-solutions)

##### [A GraphQL schema that supports input unions can be queried by older GraphQL clients](#j-a-graphql-schema-that-supports-input-unions-can-be-queried-by-older-graphql-clients)

##### [Input unions should be expressed efficiently in the query and on the wire](#k-input-unions-should-be-expressed-efficiently-in-the-query-and-on-the-wire)

The additional field bloats the query.

##### [Input unions should be performant for servers](#l-input-unions-should-be-performant-for-servers)

### 2. Single user-chosen field; value is the `type`

```graphql
input CatInput {
  kind: CatInput
  name: String!
  age: Int
  livesLeft: Int
}
input DogInput {
  kind: DogInput
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
      kind: "CatInput",
      name: "Buster",
      livesLeft: 7
    }
  ]
}
```

#### Variations:

* Value is a `Enum` literal

This solution is derived from discussions in https://github.com/graphql/graphql-spec/issues/488

```graphql
enum AnimalKind {
  CAT
  DOG
}

input CatInput {
  kind: AnimalKind::CAT
  name: String!
  age: Int
  livesLeft: Int
}
input DogInput {
  kind: AnimalKind::DOG
  name: String!
  age: Int
  breed: DogBreed
}

# Variables:
{
  location: "Portland, OR",
  animals: [
    {
      kind: "CAT",
      name: "Buster",
      livesLeft: 7
    }
  ]
}
```

* Value is a `String` literal

```graphql
input CatInput {
  kind: "cat"
  name: String!
  age: Int
  livesLeft: Int
}
input DogInput {
  kind: "dog"
  name: String!
  age: Int
  breed: DogBreed
}
```

#### Evaluation

##### [GraphQL should contain a polymorphic Input type](#a-graphql-should-contain-a-polymorphic-input-type)

##### [Input polymorphism matches output polymorphism](#b-input-polymorphism-matches-output-polymorphism)

##### [Doesn't inhibit schema evolution](#c-doesnt-inhibit-schema-evolution)

##### [Any member type restrictions are validated in schema](#d-any-member-type-restrictions-are-validated-in-schema)

##### [A member type may be a Leaf type](#e-a-member-type-may-be-a-leaf-type)

##### [Changing field from an input type to a polymorphic type including that type is non-breaking](#f-changing-field-from-an-input-type-to-a-polymorphic-type-including-that-type-is-non-breaking)

##### [Input unions may include other input unions](#g-input-unions-may-include-other-input-unions)

##### [Input unions should accept plain data from clients](#h-input-unions-should-accept-plain-data-from-clients)

No, as there is an additional field that has to be added.

##### [Input unions should be easy to upgrade from existing solutions](#i-input-unions-should-be-easy-to-upgrade-from-existing-solutions)

##### [A GraphQL schema that supports input unions can be queried by older GraphQL clients](#j-a-graphql-schema-that-supports-input-unions-can-be-queried-by-older-graphql-clients)

##### [Input unions should be expressed efficiently in the query and on the wire](#k-input-unions-should-be-expressed-efficiently-in-the-query-and-on-the-wire)

The additional field bloats the query.

##### [Input unions should be performant for servers](#l-input-unions-should-be-performant-for-servers)

### 3. Order based type matching

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

#### Evaluation

##### [GraphQL should contain a polymorphic Input type](#a-graphql-should-contain-a-polymorphic-input-type)

##### [Input polymorphism matches output polymorphism](#b-input-polymorphism-matches-output-polymorphism)

##### [Doesn't inhibit schema evolution](#c-doesnt-inhibit-schema-evolution)

Adding a nullable field to an input object could change the detected type of
fields or arguments in pre-existing operations.

Assuming we have this schema:

```graphql
input InputA {
  foo: Int
}
input InputB {
  foo: Int
  bar: Int
}
input InputC {
  foo: Int
  bar: Int
  baz: Int
}
inputUnion InputU = InputA | InputB | InputC

type A {...}
type B {...}
type C {...}
union U = A | B | C

type Query {
  field(u: InputU): U
}
```

Given this query:

```graphql
query ($u: InputU = {foo: 3, baz: 3}) {
  field(u: $u) {
    __typename
    ... on C {
      # ...
    }
  }
}
```

the default value of `$u` would be detected as type InputC. However adding the
field `baz: Int` to type InputA would result in the same value now being detected
as type InputA, which could be a breaking change for application behaviour.

##### [Any member type restrictions are validated in schema](#d-any-member-type-restrictions-are-validated-in-schema)

##### [A member type may be a Leaf type](#e-a-member-type-may-be-a-leaf-type)

##### [Changing field from an input type to a polymorphic type including that type is non-breaking](#f-changing-field-from-an-input-type-to-a-polymorphic-type-including-that-type-is-non-breaking)

##### [Input unions may include other input unions](#g-input-unions-may-include-other-input-unions)

##### [Input unions should accept plain data from clients](#h-input-unions-should-accept-plain-data-from-clients)

##### [Input unions should be easy to upgrade from existing solutions](#i-input-unions-should-be-easy-to-upgrade-from-existing-solutions)

##### [A GraphQL schema that supports input unions can be queried by older GraphQL clients](#j-a-graphql-schema-that-supports-input-unions-can-be-queried-by-older-graphql-clients)

##### [Input unions should be expressed efficiently in the query and on the wire](#k-input-unions-should-be-expressed-efficiently-in-the-query-and-on-the-wire)

##### [Input unions should be performant for servers](#l-input-unions-should-be-performant-for-servers)

### 4. Structural uniqueness

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

#### Variations:

* Consider the field _type_ along with the field _name_ when determining uniqueness.

##### [GraphQL should contain a polymorphic Input type](#a-graphql-should-contain-a-polymorphic-input-type)

##### [Input polymorphism matches output polymorphism](#b-input-polymorphism-matches-output-polymorphism)

##### [Doesn't inhibit schema evolution](#c-doesnt-inhibit-schema-evolution)

Inputs may be pushed to include extraneous fields to ensure uniqueness.

##### [Any member type restrictions are validated in schema](#d-any-member-type-restrictions-are-validated-in-schema)

##### [A member type may be a Leaf type](#e-a-member-type-may-be-a-leaf-type)

##### [Changing field from an input type to a polymorphic type including that type is non-breaking](#f-changing-field-from-an-input-type-to-a-polymorphic-type-including-that-type-is-non-breaking)

##### [Input unions may include other input unions](#g-input-unions-may-include-other-input-unions)

##### [Input unions should accept plain data from clients](#h-input-unions-should-accept-plain-data-from-clients)

##### [Input unions should be easy to upgrade from existing solutions](#i-input-unions-should-be-easy-to-upgrade-from-existing-solutions)

##### [A GraphQL schema that supports input unions can be queried by older GraphQL clients](#j-a-graphql-schema-that-supports-input-unions-can-be-queried-by-older-graphql-clients)

##### [Input unions should be expressed efficiently in the query and on the wire](#k-input-unions-should-be-expressed-efficiently-in-the-query-and-on-the-wire)

##### [Input unions should be performant for servers](#l-input-unions-should-be-performant-for-servers)

### 5. One Of (Tagged Union)

This solution was presented in:
* https://github.com/graphql/graphql-spec/pull/395#issuecomment-361373097
* https://github.com/graphql/graphql-spec/pull/586

The type is discriminated using features already available, with an intermediate input type that acts to "tag" the field.

A proposed directive would specify that only one of the fields may be selected.

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
    cat: {
      name: "Buster",
      livesLeft: 7
    }
  ]
}
```

#### Evaluation

##### [GraphQL should contain a polymorphic Input type](#a-graphql-should-contain-a-polymorphic-input-type)

##### [Input polymorphism matches output polymorphism](#b-input-polymorphism-matches-output-polymorphism)

The shape of the input type is forced to have a different structure than the
corresponding output type.

##### [Doesn't inhibit schema evolution](#c-doesnt-inhibit-schema-evolution)

##### [Any member type restrictions are validated in schema](#d-any-member-type-restrictions-are-validated-in-schema)

##### [A member type may be a Leaf type](#e-a-member-type-may-be-a-leaf-type)

##### [Changing field from an input type to a polymorphic type including that type is non-breaking](#f-changing-field-from-an-input-type-to-a-polymorphic-type-including-that-type-is-non-breaking)

##### [Input unions may include other input unions](#g-input-unions-may-include-other-input-unions)

##### [Input unions should accept plain data from clients](#h-input-unions-should-accept-plain-data-from-clients)

##### [Input unions should be easy to upgrade from existing solutions](#i-input-unions-should-be-easy-to-upgrade-from-existing-solutions)

##### [A GraphQL schema that supports input unions can be queried by older GraphQL clients](#j-a-graphql-schema-that-supports-input-unions-can-be-queried-by-older-graphql-clients)

##### [Input unions should be expressed efficiently in the query and on the wire](#k-input-unions-should-be-expressed-efficiently-in-the-query-and-on-the-wire)

##### [Input unions should be performant for servers](#l-input-unions-should-be-performant-for-servers)
