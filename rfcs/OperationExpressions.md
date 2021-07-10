# RFC: Operation Expressions

(WORKING TITLE!)

**Proposed by:** [Benjie Gillam](https://twitter.com/benjie) - Graphile

In the [Schema Coordinates RFC](./SchemaCoordinates.md) Mark introduced the
concept of "schema coordinates" which give a standard human- and
machine-readable way to unambiguously refer to entities within a GraphQL schema:
types, fields, field arguments, enum values, directives and directive arguments.
The scope of that RFC is deliberately very tight, and it serves that goal well,
providing a one-to-one mapping between the schema coordinates and the schema
entities.

This RFC is to gather feedback on expansions of the Schema Coordinate syntax
that could be used for different purposes whilst maintaining familiarity.

## Aim

The aim of this RFC is to give the GraphQL community a standard syntax that
people, tools and documentation can use to concisely and consistently reference
GraphQL operation concepts such as paths that is more fluid, expressive, and
contains more context than the Schema Coordinates RFC that this RFC builds on
top of.

This is not intended to be a replacement of the Schema Coordinates RFC, but an
extension to it for a number of additional use-cases.

## Use cases

#### Referencing a position within a GraphQL Operation Document

Imagine you have the following GraphQL query:

```graphql
{
  businesses: searchBusinesses(name: "Automotive") {
    id
    name
    owner: personByOwnerId {
      id
      name
      email # <<< HERE
    }
  }
}
```

You might reference the marked (`<<< HERE`) field with an expression such as:

- `Person.email` - this is the "schema coordinate" which uniquely identifies the
  field, but lacks context on how we retrieved it
- `>businesses>owner>email` - given the GraphQL query document, this is
  sufficient to uniquely identify this specific reference (caveat: duplicate
  fields would all be referenced with the same expression)
- `>businesses:searchBusinesses>owner:personByOwnerId>email` - this contains
  more context than the above, indicating not just the aliases but the actual
  field names too; with this access to the operation document is not required to
  determine what was requested
- `>businesses:searchBusinesses(name:)>owner:personByOwnerId>email` - this
  contains even more context (the argument names that were used)

These are all valid operation expressions, but they each convey different levels
of context.

### Generating a GraphQL Operation Document quickly (Emmet-style)

> Emmet is a plugin for many popular text editors which greatly improves HTML &
> CSS workflow:

Emmet is a popular syntax for quickly generating HTML/CSS. It's easy to imagine
how a operation expression syntax could be combined with a GraphQL schema
definition to quickly generate GraphQL queries, mutations and subscriptions with
a concise syntax. For example the expression:

`>businesses:searchBusinesses(name:)>owner:personByOwnerId>email`

might expand to:

```graphql
query($name: String!) {
  businesses: searchBusinesses(name: $name) {
    owner: personByOwnerId {
      email
    }
  }
}
```

`MyFragment:User.businesses>owner>email`

might expand to:

```graphql
fragment MyFragment on User {
  businesses {
    owner {
      email
    }
  }
}
```

### Documentation Permalinks

When navigating the GraphiQL documentation, GraphiQL maintains a stack of the
path you arrived to the current documentation page through. It could be valuable
to store this into the query string such that you could share a "documentation
stack" with someone else (or bookmark it). For example if you browsed through
the documentation via:

- `User` type
- `User.friends` field (returns a `User`)
- `User.latestMedia` field (returns a `Media` union)
- `Post` type in Media union
- `title` field

you might use a query string such as:

```
?docs=User.friends>latestMedia>Post.title
```

### Linking from a field description to an operation path

If, for example, you were to deprecate a root-level field in your schema, you
might want to indicate where the user can retrieve the equivalent data now. You
could do this by including an operation expression as part of the deprecation
reason:

> The `Query.branchesFromFork` field is being removed; please use the following
> path instead: `Query>repositories>forks>branches`

### Indicating how to access a particular field

When reading the documentation of a type in GraphiQL it currently does not
indicate how to reach a particular field. Though there are often infinitely many
paths to reach a field, often the shortest are the most valuable, so GraphiQL
could indicate a few of the shorter paths using operation expression syntax:

> `User.firstName` can be accessed through paths such as:
>
> - `>me>firstName`
> - `>articles>author>firstName`
> - `>searchMedia>Book.author>firstName`
> - `mutation>createUser>user>firstName`

### Analytics

When analysing how a GraphQL schema is used, it may be useful to track
statistics for each type, field, argument using Schema Coordinates; but it may
also be interesting to track through what paths users are finding said fields.
You could use operation expression syntax to track this:

```
counters['Query.cities>libraries>findBook(isbn:)']++
```

## Syntax

Syntax is in flux; but here's some thoughts:

#### Pathing

Following a path from one field to the next could use the `>` character; this is
already used in Apollo's GraphQL documentation browser and is intuitive for
navigation. This leaves `.` available and non-ambiguous for referring to fields
on a type, which is useful when disambiguating references on a union type, for
instance:

```
>me>media>Film.duration
```

might model:

```graphql
{
  me {
    media {
      ... on Film {
        duration
      }
    }
  }
}
```

#### Operations

The expression `>me>name` would expand to `{ me { name } }`.

If you want to create a mutation or subscription operation, you can prefix the
path with the operation type (you can do this for queries too, but just like in
operation documents, the query keyword is optional):

- `mutation>createUser>user>name` expands to
  `mutation ($input: CreateUserInput!) { createUser(input: $input) { user { name } } }`
- `subscription>currentUserUpdated>name` expands to
  `subscription { currentUserUpdated { name } }`
- `query>me>name` expands to `query { me { name } }`

You may name operations by prefixing with an operation name followed by a colon;
for example:

- `MyQuery:>me>name` and `MyQuery:query>me>name` expand to
  `query MyQuery { me { name } }`.
- `MyMutation:mutation>createUser>name` expands to
  `mutation MyMutation { createUser { name } }`.
- `MySubscription:subscription>userCreated>name` expands to
  `subscription MySubscription { userCreated { name } }`.

#### Fragments

Fragments start with a type name followed by a period: `User.friends>name`
expands to `... on User { friends { name } }`.

You can name fragments by prefixing with a fragment name and a colon:
`FriendNames:User.friends>name` expands to
`fragment FriendNames on User { friends { name } }`.

Other examples:

- `MyFragment:Node.User.fullName:name` expands to
  `fragment MyFragment on Node { ... on User { fullName: name } }`

- `MyQuery:>allEntities>edges>node>MyNodeFragment:Node.MyUserFragment:User.fullName:name`
  expands to

  ```graphql
  query MyQuery {
    allEntities {
      edges {
        node {
          ...MyNodeFragment
        }
      }
    }
  }

  fragment MyNodeFragment on Node {
    ...MyUserFragment
  }

  fragment MyUserFragment on User {
    fullName: name
  }
  ```

#### Arguments

Arguments use the same syntax as Schema Coordinates; namely parenthesis and a
colon: `>searchBusinesses(name:)>city`.

We also allow you to reference input objects used in arguments, for example:

`>searchBusinesses(where>size>greaterThan:)>city`

expands to something like:

```graphql
query($whereSizeGreaterThan: Int) {
  searchBusinesses(where: { size: { greaterThan: $whereSizeGreaterThan } }) {
    city
  }
}
```

Further we allow for multiple arguments to be specified, joined with commas:

`>searchBusinesses(where>size>greaterThan:,where>size>lessThan:,where>city>equalTo:)>name`

expands to something like:

```graphql
query(
  $whereSizeGreaterThan: Int
  $whereSizeLessThan: Int
  $whereCityEqualTo: String
) {
  searchBusinesses(
    where: {
      size: { greaterThan: $whereSizeGreaterThan, lessThan: $whereSizeLessThan }
      city: { equalTo: $whereCityEqualTo }
    }
  ) {
    name
  }
}
```

> NOTE: the following number syntax probably needs more thought. Added only for
> completeness.

We also allow `[number]` syntax to refer to a numbered entry in a list, or `[]`
to refer to the next entry; e.g.:

`>findUsers(byIds[]:,byIds[],byIds[],byIds[5])>name`

expands to something like:

```graphql
query($byIds0: ID, $byIds1: ID, $byIds2: ID, $byIds5: ID) {
  findUsers(byIds: [$byIds0, $byIds1, $byIds2, null, null, $byIds5]) {
    name
  }
}
```

## Grammar

The Lexical Tokens below plus `OperationType` and `Alias` are defined as in the
GraphQL spec. Note there are no ignored characters: **whitespace is not
ignored**.

### Lexical Tokens

Name ::
  - NameStart NameContinue* [lookahead != NameContinue]

NameStart ::
  - Letter
  - `_`

NameContinue ::
  - Letter
  - Digit
  - `_`

Letter :: one of
  `A` `B` `C` `D` `E` `F` `G` `H` `I` `J` `K` `L` `M`
  `N` `O` `P` `Q` `R` `S` `T` `U` `V` `W` `X` `Y` `Z`
  `a` `b` `c` `d` `e` `f` `g` `h` `i` `j` `k` `l` `m`
  `n` `o` `p` `q` `r` `s` `t` `u` `v` `w` `x` `y` `z`

Digit :: one of
  `0` `1` `2` `3` `4` `5` `6` `7` `8` `9`

IntValue :: IntegerPart [lookahead != {Digit, `.`, NameStart}]

IntegerPart ::
  - NegativeSign? 0
  - NegativeSign? NonZeroDigit Digit*

NegativeSign :: -

NonZeroDigit :: Digit but not `0`

Comma :: ,

### Expression Syntax

Expression :
  - FragmentExpression
  - OperationExpression

OperationExpression : Alias? OperationType? > SelectionPath

FragmentExpression : Alias? Name . SelectionPath

Alias : Name :

OperationType : one of `query` `mutation` `subscription`

SelectionPath :
 - Alias? Name . Alias? Name ( Arguments ) > SelectionPath
 - Alias? Name . Alias? Name ( Arguments )
 - Alias? Name . Alias? Name > SelectionPath
 - Alias? Name . Alias? Name
 - Alias? Name ( Arguments ) > SelectionPath
 - Alias? Name ( Arguments )
 - Alias? Name > SelectionPath
 - Alias? Name

Arguments :
 - Argument Comma Arguments
 - Argument

Argument : NamePath :

NamePath :
  - Name Indexes? > NamePath
  - Name Indexes?

Indexes :
  - Index Indexes
  - Index

Index :
  - [ IntValue ]
  - [ ]
