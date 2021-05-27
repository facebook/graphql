# Introspection

A GraphQL service supports introspection over its schema. This schema is queried
using GraphQL itself, creating a powerful platform for tool-building.

Take an example request for a trivial app. In this case there is a User type with
three fields: id, name, and birthday.

For example, given a service with the following type definition:

```graphql example
type User {
  id: String
  name: String
  birthday: Date
}
```

A request containing the operation:

```graphql example
{
  __type(name: "User") {
    name
    fields {
      name
      type {
        name
      }
    }
  }
}
```

would produce the result:

```json example
{
  "__type": {
    "name": "User",
    "fields": [
      {
        "name": "id",
        "type": { "name": "String" }
      },
      {
        "name": "name",
        "type": { "name": "String" }
      },
      {
        "name": "birthday",
        "type": { "name": "Date" }
      }
    ]
  }
}
```

**Reserved Names**

Types and fields required by the GraphQL introspection system that are used in
the same context as user-defined types and fields are prefixed with {"__"} two
underscores. This in order to avoid naming collisions with user-defined GraphQL
types.

Otherwise, any {Name} within a GraphQL type system must not start with
two underscores {"__"}.

## Type Name Introspection

GraphQL supports type name introspection within any selection set in an
operation, with the single exception of selections at the root of a subscription
operation. Type name introspection is accomplished via the meta-field
`__typename: String!` on any Object, Interface, or Union. It returns the name of
the *concrete Object type* at that point during execution.

This is most often used when querying against a Interface or Union
*abstract type* to identify which actual *concrete Object type* of the possible
types has been returned.

As a meta-field, `__typename` is implicit and does not appear in the fields list
in any defined type.

Note: `__typename` may not be included as a root field in a subscription
operation.

## Schema Introspection

The schema introspection system is accessible from the meta-fields `__schema`
and `__type` which are accessible from the type of the root of a query
operation.

```graphql
__schema: __Schema!
__type(name: String!): __Type
```

Like all meta-fields, these are implicit and do not appear in the fields list in
the root type of the query operation.

**First Class Documentation**

All types in the introspection system provide a `description` field of type
`String` to allow type designers to publish documentation in addition to
capabilities. A GraphQL service may return the `description` field using Markdown
syntax (as specified by [CommonMark](https://commonmark.org/)). Therefore it is
recommended that any tool that displays `description` use a CommonMark-compliant
Markdown renderer.

**Deprecation**

To support the management of backwards compatibility, GraphQL fields and enum
values can indicate whether or not they are deprecated (`isDeprecated: Boolean`)
and a description of why it is deprecated (`deprecationReason: String`).

Tools built using GraphQL introspection should respect deprecation by
discouraging deprecated use through information hiding or developer-facing
warnings.

**Schema Introspection Schema**

The schema introspection system is itself represented as a GraphQL schema. Below
are the full set of type system definitions providing schema introspection,
which are fully defined in the sections below.

```graphql
type __Schema {
  description: String
  types: [__Type!]!
  queryType: __Type!
  mutationType: __Type
  subscriptionType: __Type
  directives: [__Directive!]!
}

type __Type {
  kind: __TypeKind!
  name: String
  description: String
  # must be non-null for OBJECT and INTERFACE, otherwise null.
  fields(includeDeprecated: Boolean = false): [__Field!]
  # must be non-null for OBJECT and INTERFACE, otherwise null.
  interfaces: [__Type!]
  # must be non-null for INTERFACE and UNION, otherwise null.
  possibleTypes: [__Type!]
  # must be non-null for ENUM, otherwise null.
  enumValues(includeDeprecated: Boolean = false): [__EnumValue!]
  # must be non-null for INPUT_OBJECT, otherwise null.
  inputFields: [__InputValue!]
  # must be non-null for NON_NULL and LIST, otherwise null.
  ofType: __Type
  # may be non-null for custom SCALAR, otherwise null.
  specifiedByURL: String
}

enum __TypeKind {
  SCALAR
  OBJECT
  INTERFACE
  UNION
  ENUM
  INPUT_OBJECT
  LIST
  NON_NULL
}

type __Field {
  name: String!
  description: String
  args: [__InputValue!]!
  type: __Type!
  isDeprecated: Boolean!
  deprecationReason: String
}

type __InputValue {
  name: String!
  description: String
  type: __Type!
  defaultValue: String
}

type __EnumValue {
  name: String!
  description: String
  isDeprecated: Boolean!
  deprecationReason: String
}

type __Directive {
  name: String!
  description: String
  locations: [__DirectiveLocation!]!
  args: [__InputValue!]!
  isRepeatable: Boolean!
}

enum __DirectiveLocation {
  QUERY
  MUTATION
  SUBSCRIPTION
  FIELD
  FRAGMENT_DEFINITION
  FRAGMENT_SPREAD
  INLINE_FRAGMENT
  VARIABLE_DEFINITION
  SCHEMA
  SCALAR
  OBJECT
  FIELD_DEFINITION
  ARGUMENT_DEFINITION
  INTERFACE
  UNION
  ENUM
  ENUM_VALUE
  INPUT_OBJECT
  INPUT_FIELD_DEFINITION
}
```

### The __Schema Type

The `__Schema` type is returned from the `__schema` meta-field and provides
all information about the schema of a GraphQL service.

Fields\:

* `description` may return a String or {null}.
* `queryType` is the root type of a query operation.
* `mutationType` is the root type of a mutation operation, if supported.
  Otherwise {null}.
* `subscriptionType` is the root type of a subscription operation, if supported.
  Otherwise {null}.
* `types` must return the set of all *named type* contained within this schema.
  Any named type which can be found through a field of any introspection type
  must be included in this set.
* `directives` must return the set of all directives available within
  this schema including all built-in directives.


### The __Type Type

`__Type` is at the core of the type introspection system, it represents all
types in the system: both *named types* (e.g. *Scalar type* or *Object type*)
and *wrapped types* (e.g. *List type* or *Non-Null type*).

There are several different kinds of type. In each kind, different fields are
actually valid. All possible kinds are listed in the `__TypeKind` enum.

Each sub-section below defines the expected fields of `__Type` given each
possible value of the `__TypeKind` enum:

* {"SCALAR"}
* {"OBJECT"}
* {"INTERFACE"}
* {"UNION"}
* {"ENUM"}
* {"INPUT_OBJECT"}
* {"LIST"}
* {"NON_NULL"}

**Scalar**

Represents a *scalar type* such as Int, String, and Boolean. Scalars cannot have
fields.

Also represents a *custom scalar type* which may provide `specifiedByURL` as a
*scalar specification URL*.

Fields\:

* `kind` must return `__TypeKind.SCALAR`.
* `name` must return a String.
* `description` may return a String or {null}.
* `specifiedByURL` may return a String (in the form of a URL) for custom
  scalars, otherwise must be {null}.
* All other fields must return {null}.


**Object**

An *Object type* represents concrete instantiations of sets of fields. The
introspection types (e.g. `__Type`, `__Field`, etc) are themselves examples of
object types.

Fields\:

* `kind` must return `__TypeKind.OBJECT`.
* `name` must return a String.
* `description` may return a String or {null}.
* `fields` must return the set of fields that can be selected for this type.
  * Accepts the argument `includeDeprecated` which defaults to {false}. If
    {true}, deprecated fields are also returned.
* `interfaces` must return the set of interfaces that an object implements
  (if none, `interfaces` must return the empty set).
* All other fields must return {null}.


**Interface**

An *Interface type* is an *abstract type* where there are common fields
declared. Any type that implements an interface must define all the fields with
names and types exactly matching. The implementations of this interface are
explicitly listed out in `possibleTypes`.

Fields\:

* `kind` must return `__TypeKind.INTERFACE`.
* `name` must return a String.
* `description` may return a String or {null}.
* `fields` must return the set of fields required by this interface.
  * Accepts the argument `includeDeprecated` which defaults to {false}. If
    {true}, deprecated fields are also returned.
* `interfaces` must return the set of interfaces that an object implements
  (if none, `interfaces` must return the empty set).
* `possibleTypes` returns the list of types that implement this interface.
  They must each be an *Object type*.
* All other fields must return {null}.


**Union**

A *Union type* is an *abstract type* where no common fields are declared. The
possible types of a union are explicitly listed out in `possibleTypes`. The
possible types of a union do not directly reference the union type.

Fields\:

* `kind` must return `__TypeKind.UNION`.
* `name` must return a String.
* `description` may return a String or {null}.
* `possibleTypes` returns the list of types that can be represented within this
  union. They must each be an *Object type*.
* All other fields must return {null}.


**Enum**

An *Enum type* is a *leaf type* that represents a defined set of possible
values.

Fields\:

* `kind` must return `__TypeKind.ENUM`.
* `name` must return a String.
* `description` may return a String or {null}.
* `enumValues` must return the set of enum values as a list of `__EnumValue`.
  There must be at least one and they must have unique names.
  * Accepts the argument `includeDeprecated` which defaults to {false}. If
    {true}, deprecated enum values are also returned.
* All other fields must return {null}.


**Input Object**

An *Input Object type* is a composite *input type* defined as a set of
*input type* fields. They are only used as inputs to arguments and variables and
cannot be a field return type.

For example the Input Object `Point` could be defined as:

```graphql example
input Point {
  x: Int
  y: Int
}
```

Fields\:

* `kind` must return `__TypeKind.INPUT_OBJECT`.
* `name` must return a String.
* `description` may return a String or {null}.
* `inputFields` must return the set of input fields as a list of `__InputValue`.
* All other fields must return {null}.


**List**

A *List type* is a *wrapped type* which represents an ordered collection of
values. It wraps an *item type* in the `ofType` field which defines the type of
each item in the list.

A List type's *item type* in the `ofType` field may itself be a *wrapped type*,
allowing the representation of Lists of Lists, or Lists of Non-Nulls.

Fields\:

* `kind` must return `__TypeKind.LIST`.
* `ofType` must return a type of any kind.
* All other fields must return {null}.


**Non-Null**

A *Non-Null type* is a *wrapped type* which represents a value which must not be
{null}. It wraps a *nullable type* in the `ofType` field which defines the
expected type of a value if not {null}.

A Non-Null type's *nullable type* in the `ofType` field may be a *List type*,
allowing the representation of Non-Null of Lists. However it must not be another
*Non-Null type* to avoid a redundant Non-Null of Non-Null.

Fields\:

* `kind` must return `__TypeKind.NON_NULL`.
* `ofType` must return a type of any kind except Non-Null.
* All other fields must return {null}.


### The __Field Type

The `__Field` type represents each field in an Object or Interface type.

Fields\:

* `name` must return a String
* `description` may return a String or {null}
* `args` returns a List of `__InputValue` representing the arguments this
  field accepts.
* `type` must return a `__Type` that represents the type of value returned by
  this field.
* `isDeprecated` returns {true} if this field should no longer be used,
  otherwise {false}.
* `deprecationReason` optionally provides a reason why this field is deprecated.


### The __InputValue Type

The `__InputValue` type represents field and directive arguments as well as the
`inputFields` of an *Input Object type*.

Fields\:

* `name` must return a String
* `description` may return a String or {null}
* `type` must return a `__Type` that represents the type this input
  value expects.
* `defaultValue` may return a String encoding (using the GraphQL language) of the
  default value used by this input value in the condition a value is not
  provided at runtime. If this input value has no default value, returns {null}.

### The __EnumValue Type

The `__EnumValue` type represents one of possible values of an enum.

Fields\:

* `name` must return a String
* `description` may return a String or {null}
* `isDeprecated` returns {true} if this enum value should no longer be used,
  otherwise {false}.
* `deprecationReason` optionally provides a reason why this enum value is deprecated.

### The __Directive Type

The `__Directive` type represents a directive that a service supports.

This includes both any *built-in directive* and any *custom directive*.

Individual directives may only be used in locations that are explicitly
supported. All possible locations are listed in the `__DirectiveLocation` enum:

* {"QUERY"}
* {"MUTATION"}
* {"SUBSCRIPTION"}
* {"FIELD"}
* {"FRAGMENT_DEFINITION"}
* {"FRAGMENT_SPREAD"}
* {"INLINE_FRAGMENT"}
* {"VARIABLE_DEFINITION"}
* {"SCHEMA"}
* {"SCALAR"}
* {"OBJECT"}
* {"FIELD_DEFINITION"}
* {"ARGUMENT_DEFINITION"}
* {"INTERFACE"}
* {"UNION"}
* {"ENUM"}
* {"ENUM_VALUE"}
* {"INPUT_OBJECT"}
* {"INPUT_FIELD_DEFINITION"}

Fields\:

* `name` must return a String
* `description` may return a String or {null}
* `locations` returns a List of `__DirectiveLocation` representing the valid
  locations this directive may be placed.
* `args` returns a List of `__InputValue` representing the arguments this
  directive accepts.
* `isRepeatable` must return a Boolean that indicates if the directive may be
  used repeatedly at a single location.
