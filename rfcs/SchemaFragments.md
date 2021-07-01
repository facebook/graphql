# RFC: Schema Fragments

## Problem

When writing large schemas, there is no way to reuse similar fields between `ObjectTypeDefinition`(s) and `InputValueDefinition`(s). One can use [interfaces](https://spec.graphql.org/June2018/#sec-Interfaces) to enforce that particular fields are implemented, though this doesn't really help, as a schema creator I still have to repeat X fields on X amount of types.

Below I have `Users`(s) and `Post`(s) and where both types have the following properties; `id`, `createdAt` and `updatedAt`:

```graphql
type User {
  id: ID # Repeated
  createdAt: DateTime # Repeated
  updatedAt: DateTime # Repeated
  name: String
}

type Post {
  id: ID # Repeated
  createdAt: DateTime # Repeated
  updatedAt: DateTime # Repeated
  content: String
}
```

> Notice how the three properties are repeated.

As mentioned, you can use interfaces here, so for example a `BaseInterface` that contains the properties, and then this is implemented on each type:

```graphql
interface BaseInterface {
  id: ID # Repeated
  createdAt: DateTime # Repeated
  updatedAt: DateTime # Repeated
}

type User implements BaseInterface {
  id: ID # Repeated
  createdAt: DateTime # Repeated
  updatedAt: DateTime # Repeated
  name: String
}

type Post implements BaseInterface {
  id: ID # Repeated
  createdAt: DateTime # Repeated
  updatedAt: DateTime # Repeated
  content: String
}
```

However, this isn't helpful at scale because your still repeating each field.

## Solution

Enable the usage of fragments on `ObjectTypeDefinition`(s) and `InputValueDefinition`(s) to reduce the repetition of common fields.

Below I have `Users`(s) and `Post`(s) and where both types have the following properties; `id`, `createdAt` and `updatedAt`. The listed properties are only defined once and I use the fragment spread syntax to apply them to each type:

```graphql
fragment BaseInterface on ObjectTypeDefinition {
  id: ID
  createdAt: DateTime
  updatedAt: DateTime
}

type User {
  ...BaseInterface
  name: String
}

type Post {
  ...BaseInterface
  content: String
}
```

## Implementation

I assume that the GraphQL parser would need to be adapted to allow the usage of fragments on the fields, and then I see it being something that your tool should implement similar to how interfaces are enforced.
