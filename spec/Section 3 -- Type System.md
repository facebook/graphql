# Type System

The GraphQL Type system describes the capabilities of a GraphQL service and is
used to determine if a requested operation is valid, to guarantee the type of
response results, and describes the input types of variables to determine if
values provided at request time are valid.

TypeSystemDocument : TypeSystemDefinition+

TypeSystemDefinition :
  - SchemaDefinition
  - TypeDefinition
  - DirectiveDefinition

The GraphQL language includes an
[IDL](https://en.wikipedia.org/wiki/Interface_description_language) used to
describe a GraphQL service's type system. Tools may use this definition language
to provide utilities such as client code generation or service boot-strapping.

GraphQL tools or services which only seek to execute GraphQL requests and not
construct a new GraphQL schema may choose not to allow {TypeSystemDefinition}.
Tools which only seek to produce schema and not execute requests may choose to
only allow {TypeSystemDocument} and not allow {ExecutableDefinition} or
{TypeSystemExtension} but should provide a descriptive error if present.

Note: The type system definition language is used throughout the remainder of
this specification document when illustrating example type systems.


## Type System Extensions

TypeSystemExtensionDocument : TypeSystemDefinitionOrExtension+

TypeSystemDefinitionOrExtension :
  - TypeSystemDefinition
  - TypeSystemExtension

TypeSystemExtension :
  - SchemaExtension
  - TypeExtension

Type system extensions are used to represent a GraphQL type system which has
been extended from some original type system. For example, this might be used by
a local service to represent data a GraphQL client only accesses locally, or by
a GraphQL service which is itself an extension of another GraphQL service.

Tools which only seek to produce and extend schema and not execute requests may
choose to only allow {TypeSystemExtensionDocument} and not allow
{ExecutableDefinition} but should provide a descriptive error if present.


## Descriptions

Description : StringValue

Documentation is a first-class feature of GraphQL type systems. To ensure
the documentation of a GraphQL service remains consistent with its capabilities,
descriptions of GraphQL definitions are provided alongside their definitions and
made available via introspection.

To allow GraphQL service designers to easily publish documentation alongside the
capabilities of a GraphQL service, GraphQL descriptions are defined using the
Markdown syntax (as specified by [CommonMark](https://commonmark.org/)). In the
type system definition language, these description strings (often {BlockString})
occur immediately before the definition they describe.

GraphQL schema and all other definitions (e.g. types, fields, arguments, etc.)
which can be described should provide a {Description} unless they are considered
self descriptive.

As an example, this simple GraphQL schema is well described:

```raw graphql example
"""
A simple GraphQL schema which is well described.
"""
schema {
  query: Query
}

"""
Root type for all your query operations
"""
type Query {
  """
  Translates a string from a given language into a different language.
  """
  translate(
    "The original language that `text` is provided in."
    fromLanguage: Language

    "The translated language to be returned."
    toLanguage: Language

    "The text to be translated."
    text: String
  ): String
}

"""
The set of languages supported by `translate`.
"""
enum Language {
  "English"
  EN

  "French"
  FR

  "Chinese"
  CH
}
```


## Schema

SchemaDefinition : Description? schema Directives[Const]? { RootOperationTypeDefinition+ }

RootOperationTypeDefinition : OperationType : NamedType

A GraphQL service's collective type system capabilities are referred to as that
service's "schema". A schema is defined in terms of the types and directives it
supports as well as the root operation types for each kind of operation:
query, mutation, and subscription; this determines the place in the type system
where those operations begin.

A GraphQL schema must itself be internally valid. This section describes
the rules for this validation process where relevant.

All types within a GraphQL schema must have unique names. No two provided types
may have the same name. No provided type may have a name which conflicts with
any built in types (including Scalar and Introspection types).

All directives within a GraphQL schema must have unique names.

All types and directives defined within a schema must not have a name which
begins with {"__"} (two underscores), as this is used exclusively by GraphQL's
introspection system.

### Root Operation Types

A schema defines the initial root operation type for each kind of operation it
supports: query, mutation, and subscription; this determines the place in the
type system where those operations begin.

The {`query`} root operation type must be provided and must be an Object type.

The {`mutation`} root operation type is optional; if it is not provided, the
service does not support mutations. If it is provided, it must be an
Object type.

Similarly, the {`subscription`} root operation type is also optional; if it is
not provided, the service does not support subscriptions. If it is provided, it
must be an Object type.

The {`query`}, {`mutation`}, and {`subscription`} root types must all be
different types if provided.

The fields on the {`query`} root operation type indicate what fields are
available at the top level of a GraphQL query operation.

For example, this example operation:

```graphql example
query {
  myName
}
```

is only valid when the {`query`} root operation type has a field named "myName":

```graphql example
type Query {
  myName: String
}
```

Similarly, the following mutation is only valid if the {`mutation`} root
operation type has a field named "setName".

```graphql example
mutation {
  setName(name: "Zuck") {
    newName
  }
}
```

When using the type system definition language, a document must include at most
one {`schema`} definition.

In this example, a GraphQL schema is defined with both query and mutation
root operation types:

```graphql example
schema {
  query: MyQueryRootType
  mutation: MyMutationRootType
}

type MyQueryRootType {
  someField: String
}

type MyMutationRootType {
  setSomeField(to: String): String
}
```

**Default Root Operation Type Names**

While any type can be the root operation type for a GraphQL operation, the type
system definition language can omit the schema definition when the {`query`},
{`mutation`}, and {`subscription`} root types are named {"Query"}, {"Mutation"},
and {"Subscription"} respectively.

Likewise, when representing a GraphQL schema using the type system definition
language, a schema definition should be omitted if it only uses the default root
operation type names.

This example describes a valid complete GraphQL schema, despite not explicitly
including a {`schema`} definition. The {"Query"} type is presumed to be the
{`query`} root operation type of the schema.

```graphql example
type Query {
  someField: String
}
```

### Schema Extension

SchemaExtension :
  - extend schema Directives[Const]? { RootOperationTypeDefinition+ }
  - extend schema Directives[Const] [lookahead != `{`]

Schema extensions are used to represent a schema which has been extended from
an original schema. For example, this might be used by a GraphQL service which
adds additional operation types, or additional directives to an existing schema.

Note: Schema extensions without additional operation type definitions must not
be followed by a {`{`} (such as a query shorthand) to avoid parsing ambiguity.
The same limitation applies to the type definitions and extensions below.

**Schema Validation**

Schema extensions have the potential to be invalid if incorrectly defined.

1. The Schema must already be defined.
2. Any non-repeatable directives provided must not already apply to the
   original Schema.


## Types

TypeDefinition :
  - ScalarTypeDefinition
  - ObjectTypeDefinition
  - InterfaceTypeDefinition
  - UnionTypeDefinition
  - EnumTypeDefinition
  - InputObjectTypeDefinition

The fundamental unit of any GraphQL Schema is the type. There are six kinds
of *named type* and two kinds of *wrapped type* definitions in GraphQL.

:: A *named type* is one of the six types defined with a name: *Scalar type*,
*Enum type*, *Object type*, *Interface type*, *Union type*,
and *Input Object type*.


### Leaf and Composite Types

The *named type* definitions are divided into leaf types and composite types,
which together can compose to represent complex type hierarchies.

:: A *leaf type* is found at the leaves in a response tree. There are two kinds
of leaf types: *Scalar type* and *Enum type*.

The most common *leaf type* is the *Scalar type*. GraphQL defines a set of
*built-in scalars* for representing common primitive values and also allows a
service to additionally provide a *custom scalar type* to represent any value.

Oftentimes, the possible values for a *leaf type* are enumerable. GraphQL offers
the *Enum type* in those cases, where each enum type definition specifies a set
of possible values.

:: A *composite type* composes other types together as a set of named fields,
allowing the composition of arbitrary type hierarchies and nested trees of data.
There are three composite *output type*: Object, Interface, and Union, and one
composite *input type*: Input Object.

The *Object type* is the concrete output *composite type* which describes an
actual concrete value which a field will resolve to during execution, composed
of other *output type* fields, allowing responses of nested data.

Oftentimes it is useful to provide a *composite type* as an *input type* to a
field argument or variable; the *Input Object type* composes a set of
*input type* fields, allowing inputs of nested data.


### Abstract Types

Object fields describe the type they resolve to, however a field may not always
know the exact resolved type until execution. A field can declare that it will
resolve to one of a set of possible types by using an abstract type.

:: An *abstract type* defines a set of possible types, one of which will be
resolved during field execution. There are two kinds of abstract types:
*Interface type* and *Union type*.

:: The type an abstract type resolves to during execution is referred to as the
*concrete Object type*, which is always an *Object type*.

An *Interface type* defines a list of fields. Any type which implements an
interface must implement those fields. Whenever a field claims it will
return an *Interface type*, it will return an implementing
*concrete Object type* during field execution.

A *Union type* defines a list of possible types. Similar to Interfaces,
whenever a field claims it will return a *Union type*, it will return one of the
possible types as the *concrete Object type* during field execution.


### Wrapped Types

All of the types so far are assumed to be both nullable and singular: e.g. a
scalar string returns either {null} or a singular string.

:: A *wrapped type* wraps another type (its *inner type*) to create a collection
or variation of that type. There are two kinds of wrapped types: *List type* and
*Non-Null type*.

:: The *inner type* is the type immediately wrapped by a *wrapped type*, which
itself may be a *wrapped type* allowing for combinations of *wrapped type*. If
continuously unwrapped, ultimately a *named type* is found.

A GraphQL schema may describe that a field or argument expects a list of another
type; the *List type* is provided for this purpose, which has an *item type* as
its *inner type*, describing the items in the list.

Similarly, a field or argument may describe that it must never be {null}. The
*Non-Null type* is provided for this purpose, which has a *nullable type* as
its *inner type* describing the expected type, if not {null}.


### Input and Output Types

Types are used throughout GraphQL to describe both the values accepted as input
to arguments and variables as well as the values output by fields. These two
uses categorize types as an *input type* or an *output type*. Some kinds of
types, like Scalar and Enum types, can be used as both input types and output
types; other kinds of types can only be used in one or the other.

:: An *input type* is a *Scalar type*, *Enum type*, *Input Object type*, or a
*wrapped type* of one of these types.

IsInputType(type) :
  * If {type} is a *wrapped type* (a *List type* or *Non-Null type*):
    * Let {innerType} be the *inner type* of {type}.
    * Return IsInputType({innerType})
  * If {type} is a Scalar, Enum, or Input Object type:
    * Return {true}
  * Return {false}

:: An *output type* is a *Scalar type*, *Enum type*, *Object type*,
*Interface Type*, *Union Type* or a *wrapped type* of one of these types.

IsOutputType(type) :
  * If {type} is a *wrapped type* (a *List type* or *Non-Null type*):
    * Let {innerType} be the *inner type* of {type}.
    * Return IsOutputType({innerType})
  * If {type} is a Scalar, Enum, Object, Interface, or Union type:
    * Return {true}
  * Return {false}


### Type Extensions

TypeExtension :
  - ScalarTypeExtension
  - ObjectTypeExtension
  - InterfaceTypeExtension
  - UnionTypeExtension
  - EnumTypeExtension
  - InputObjectTypeExtension

Type extensions are used to represent a GraphQL type which has been extended
from some original type. For example, this might be used by a local service to
represent additional fields a GraphQL client only accesses locally.


## Scalars

ScalarTypeDefinition : Description? scalar Name Directives[Const]?

:: A *Scalar type* is a *leaf type* in a GraphQL type system, and represents
(along with *Enum types*) the leaf values in a GraphQL response value or input
value. A Scalar type typically represents a primitive value, like a string,
boolean, or number.

GraphQL provides a number of *built-in scalars* representing common primitive
values which are fully defined in the sections below, however type systems may
also add any additional *custom scalar type* to introduce additional semantic
meaning representing any value.

**Built-in Scalars**

:: GraphQL specifies a basic set of well-defined *built-in scalars*: {Int},
{Float}, {String}, {Boolean}, and {ID}. A GraphQL framework should support all
of these types, and a GraphQL service which provides a type by these names must
adhere to the behavior described for them in this document. As an example, a
service must not include a type called {Int} and use it to represent 64-bit
numbers, internationalization information, or anything other than what is
defined in this document.

When returning the set of types from the `__Schema` introspection type, all
referenced *built-in scalars* must be included. If a built-in scalar type is not
referenced anywhere in a schema (there is no field, argument, or input field of
that type) then it must not be included.

When representing a GraphQL schema using the type system definition language,
all *built-in scalars* must be omitted for brevity.

**Custom Scalars**

:: GraphQL services may use a *custom scalar type* in addition to the built-in
scalars. For example, a GraphQL service could define a scalar called `UUID`
which, while serialized as a string, conforms to [RFC 4122](https://tools.ietf.org/html/rfc4122).
When querying a field of type `UUID`, you can then rely on the ability to parse
the result with a RFC 4122 compliant parser. Another example of a potentially
useful custom scalar is `URL`, which serializes as a string, but is guaranteed
by the server to be a valid URL.

:: When defining a custom scalar, GraphQL services should provide a *scalar
specification URL* via the `@specifiedBy` directive or the `specifiedByURL`
introspection field. This URL must link to a human-readable specification of the
data format, serialization, and coercion rules for the scalar.

For example, a GraphQL service providing a `UUID` scalar may link to RFC 4122,
or some custom document defining a reasonable subset of that RFC. If a *scalar
specification URL* is present, systems and tools that are aware of it should
conform to its described rules.

```graphql example
scalar UUID @specifiedBy(url: "https://tools.ietf.org/html/rfc4122")
scalar URL @specifiedBy(url: "https://tools.ietf.org/html/rfc3986")
```

Custom *scalar specification URL*s should provide a single, stable format to
avoid ambiguity. If the linked specification is in flux, the service should link
to a fixed version rather than to a resource which might change.

Custom *scalar specification URL*s should not be changed once defined. Doing so
would likely disrupt tooling or could introduce breaking changes within the
linked specification's contents.

Built-in scalar types must not provide a *scalar specification URL* as they are
specified by this document.

Note: Custom scalars should also summarize the specified format and provide
examples in their description.

**Result Coercion and Serialization**

A GraphQL service, when preparing a field of a given scalar type, must uphold the
contract the scalar type describes, either by coercing the value or producing a
[field error](#sec-Errors.Field-errors) if a value cannot be coerced or if
coercion may result in data loss.

A GraphQL service may decide to allow coercing different internal types to the
expected return type. For example when coercing a field of type {Int} a boolean
{true} value may produce {1} or a string value {"123"} may be parsed as base-10
{123}. However if internal type coercion cannot be reasonably performed without
losing information, then it must raise a field error.

Since this coercion behavior is not observable to clients of the GraphQL service,
the precise rules of coercion are left to the implementation. The only
requirement is that the service must yield values which adhere to the expected
Scalar type.

GraphQL scalars are serialized according to the serialization format being used.
There may be a most appropriate serialized primitive for each given scalar type,
and the service should produce each primitive where appropriate.

See [Serialization Format](#sec-Serialization-Format) for more detailed
information on the serialization of scalars in common JSON and other formats.

**Input Coercion**

If a GraphQL service expects a scalar type as input to an argument, coercion
is observable and the rules must be well defined. If an input value does not
match a coercion rule, a [request error](#sec-Errors.Request-errors) must be
raised (input values are validated before execution begins).

GraphQL has different constant literals to represent integer and floating-point
input values, and coercion rules may apply differently depending on which type
of input value is encountered. GraphQL may be parameterized by variables, the
values of which are often serialized when sent over a transport like HTTP. Since
some common serializations (ex. JSON) do not discriminate between integer
and floating-point values, they are interpreted as an integer input value if
they have an empty fractional part (ex. `1.0`) and otherwise as floating-point
input value.

For all types below, with the exception of Non-Null, if the explicit value
{null} is provided, then the result of input coercion is {null}.


### Int

The Int scalar type represents a signed 32-bit numeric non-fractional value.
Response formats that support a 32-bit integer or a number type should use
that type to represent this scalar.

**Result Coercion**

Fields returning the type {Int} expect to encounter 32-bit integer
internal values.

GraphQL services may coerce non-integer internal values to integers when
reasonable without losing information, otherwise they must raise a field error.
Examples of this may include returning `1` for the floating-point number `1.0`,
or returning `123` for the string `"123"`. In scenarios where coercion may lose
data, raising a field error is more appropriate. For example, a floating-point
number `1.2` should raise a field error instead of being truncated to `1`.

If the integer internal value represents a value less than -2<sup>31</sup> or
greater than or equal to 2<sup>31</sup>, a field error should be raised.

**Input Coercion**

When expected as an *input type*, only integer input values are accepted. All
other input values, including strings with numeric content, must raise a request
error indicating an incorrect type. If the integer input value represents a
value less than -2<sup>31</sup> or greater than or equal to 2<sup>31</sup>, a
request error should be raised.

Note: Numeric integer values larger than 32-bit should either use String or a
custom-defined Scalar type, as not all platforms and transports support
encoding integer numbers larger than 32-bit.


### Float

The Float scalar type represents signed double-precision finite values as
specified by [IEEE 754](https://en.wikipedia.org/wiki/IEEE_floating_point).
Response formats that support an appropriate double-precision number type should
use that type to represent this scalar.

**Result Coercion**

Fields returning the type {Float} expect to encounter double-precision
floating-point internal values.

GraphQL services may coerce non-floating-point internal values to {Float} when
reasonable without losing information, otherwise they must raise a field error.
Examples of this may include returning `1.0` for the integer number `1`, or
`123.0` for the string `"123"`.

Non-finite floating-point internal values ({NaN} and {Infinity}) cannot be
coerced to {Float} and must raise a field error.

**Input Coercion**

When expected as an *input type*, both integer and float input values are
accepted. Integer input values are coerced to Float by adding an empty
fractional part, for example `1.0` for the integer input value `1`. All
other input values, including strings with numeric content, must raise a request
error indicating an incorrect type. If the input value otherwise represents a
value not representable by finite IEEE 754 (e.g. {NaN}, {Infinity}, or a value
outside the available precision), a request error must be raised.


### String

The String scalar type represents textual data, represented as a sequence of
Unicode code points. The String type is most often used by GraphQL to
represent free-form human-readable text. How the String is encoded internally
(for example UTF-8) is left to the service implementation. All response
serialization formats must support a string representation (for example, JSON
Unicode strings), and that representation must be used to serialize this type.

**Result Coercion**

Fields returning the type {String} expect to encounter Unicode string values.

GraphQL services may coerce non-string raw values to {String} when reasonable
without losing information, otherwise they must raise a field error. Examples of
this may include returning the string `"true"` for a boolean true value, or the
string `"1"` for the integer `1`.

**Input Coercion**

When expected as an *input type*, only valid Unicode string input values are
accepted. All other input values must raise a request error indicating an
incorrect type.


### Boolean

The Boolean scalar type represents `true` or `false`. Response formats should
use a built-in boolean type if supported; otherwise, they should use their
representation of the integers `1` and `0`.

**Result Coercion**

Fields returning the type {Boolean} expect to encounter boolean internal values.

GraphQL services may coerce non-boolean raw values to {Boolean} when reasonable
without losing information, otherwise they must raise a field error. Examples of
this may include returning `true` for non-zero numbers.

**Input Coercion**

When expected as an *input type*, only boolean input values are accepted. All
other input values must raise a request error indicating an incorrect type.


### ID

The ID scalar type represents a unique identifier, often used to refetch an
object or as the key for a cache. The ID type is serialized in the same way as
a {String}; however, it is not intended to be human-readable. While it is
often numeric, it should always serialize as a {String}.

**Result Coercion**

GraphQL is agnostic to ID format, and serializes to string to ensure consistency
across many formats ID could represent, from small auto-increment numbers, to
large 128-bit random numbers, to base64 encoded values, or string values of a
format like [GUID](https://en.wikipedia.org/wiki/Globally_unique_identifier).

GraphQL services should coerce as appropriate given the ID formats they expect.
When coercion is not possible they must raise a field error.

**Input Coercion**

When expected as an *input type*, any string (such as `"4"`) or integer (such as
`4` or `-4`) input value should be coerced to ID as appropriate for the ID
formats a given GraphQL service expects. Any other input value, including float
input values (such as `4.0`), must raise a request error indicating an incorrect
type.


### Scalar Extensions

ScalarTypeExtension :
  - extend scalar Name Directives[Const]

Scalar type extensions are used to represent a scalar type which has been
extended from some original scalar type. For example, this might be used by a
GraphQL tool or service which adds directives to an existing scalar.

**Type Validation**

Scalar type extensions have the potential to be invalid if incorrectly defined.

1. The named type must already be defined and must be a Scalar type.
2. Any non-repeatable directives provided must not already apply to the
   original Scalar type.


## Objects

ObjectTypeDefinition :
  - Description? type Name ImplementsInterfaces? Directives[Const]? FieldsDefinition
  - Description? type Name ImplementsInterfaces? Directives[Const]? [lookahead != `{`]

ImplementsInterfaces :
  - ImplementsInterfaces & NamedType
  - implements `&`? NamedType

FieldsDefinition : { FieldDefinition+ }

FieldDefinition : Description? Name ArgumentsDefinition? : Type Directives[Const]?

GraphQL operations are hierarchical and composed, describing a tree of
information. While Scalar types describe the leaf values of these hierarchical
operations, Objects describe the intermediate levels.

:: An *Object type* represents a list of named fields, each of which yield a
value of a specific type. Object values should be serialized as ordered maps,
where the selected field names (or aliases) are the keys and the result of
evaluating the field is the value, ordered by the order in which they appear in
the selection set.

All fields defined within an Object type must not have a name which begins with
{"__"} (two underscores), as this is used exclusively by GraphQL's
introspection system.

For example, a type `Person` could be described as:

```graphql example
type Person {
  name: String
  age: Int
  picture: Url
}
```

Where `name` is a field that will yield a {String} value, and `age` is a field
that will yield an {Int} value, and `picture` is a field that will yield a
`Url` value.

A query of an object value must select at least one field. This selection of
fields will yield an ordered map containing exactly the subset of the object
queried, which should be represented in the order in which they were queried.
Only fields that are declared on the object type may validly be queried on
that object.

For example, selecting all the fields of `Person`:

```graphql example
{
  name
  age
  picture
}
```

Would yield the object:

```json example
{
  "name": "Mark Zuckerberg",
  "age": 30,
  "picture": "http://some.cdn/picture.jpg"
}
```

While selecting a subset of fields:

```graphql example
{
  age
  name
}
```

Must only yield exactly that subset:

```json example
{
  "age": 30,
  "name": "Mark Zuckerberg"
}
```

A field of an Object type must be an *output type*.

For example, the `Person` type might include a `relationship`:

```graphql example
type Person {
  name: String
  age: Int
  picture: Url
  relationship: Person
}
```

Valid operations must supply a nested field set for any field that returns an
object, so this operation is not valid:

```graphql counter-example
{
  name
  relationship
}
```

However, this example is valid:

```graphql example
{
  name
  relationship {
    name
  }
}
```

And will yield the subset of each object type queried:

```json example
{
  "name": "Mark Zuckerberg",
  "relationship": {
    "name": "Priscilla Chan"
  }
}
```

**Field Ordering**

When querying an Object, the resulting mapping of fields are conceptually
ordered in the same order in which they were encountered during execution,
excluding fragments for which the type does not apply and fields or
fragments that are skipped via `@skip` or `@include` directives. This ordering
is correctly produced when using the {CollectFields()} algorithm.

Response serialization formats capable of representing ordered maps should
maintain this ordering. Serialization formats which can only represent unordered
maps (such as JSON) should retain this order textually. That is, if two fields
`{foo, bar}` were queried in that order, the resulting JSON serialization
should contain `{"foo": "...", "bar": "..."}` in the same order.

Producing a response where fields are represented in the same order in which
they appear in the request improves human readability during debugging and
enables more efficient parsing of responses if the order of properties can
be anticipated.

If a fragment is spread before other fields, the fields that fragment specifies
occur in the response before the following fields.

```graphql example
{
  foo
  ...Frag
  qux
}

fragment Frag on Query {
  bar
  baz
}
```

Produces the ordered result:

```json example
{
  "foo": 1,
  "bar": 2,
  "baz": 3,
  "qux": 4
}
```

If a field is queried multiple times in a selection, it is ordered by the first
time it is encountered. However fragments for which the type does not apply does
not affect ordering.

```graphql example
{
  foo
  ...Ignored
  ...Matching
  bar
}

fragment Ignored on UnknownType {
  qux
  baz
}

fragment Matching on Query {
  bar
  qux
  foo
}
```

Produces the ordered result:

```json example
{
  "foo": 1,
  "bar": 2,
  "qux": 3
}
```

Also, if directives result in fields being excluded, they are not considered in
the ordering of fields.

```graphql example
{
  foo @skip(if: true)
  bar
  foo
}
```

Produces the ordered result:

```json example
{
  "bar": 1,
  "foo": 2
}
```

**Result Coercion**

Determining the result of coercing an object is the heart of the GraphQL
executor, so this is covered in that section of the spec.

**Input Coercion**

Objects are never valid inputs.

**Type Validation**

Object types have the potential to be invalid if incorrectly defined. This set
of rules must be adhered to by every Object type in a GraphQL schema.

1. An Object type must define one or more fields.
2. For each field of an Object type:
   1. The field must have a unique name within that Object type;
      no two fields may share the same name.
   2. The field must not have a name which begins with the
      characters {"__"} (two underscores).
   3. The field must return a type where {IsOutputType(fieldType)} returns {true}.
   4. For each argument of the field:
      1. The argument must not have a name which begins with the
         characters {"__"} (two underscores).
      2. The argument must accept a type where {IsInputType(argumentType)}
         returns {true}.
3. An object type may declare that it implements one or more unique interfaces.
4. An object type must be a super-set of all interfaces it implements:
   1. Let this object type be {objectType}.
   2. For each interface declared implemented as {interfaceType},
      {IsValidImplementation(objectType, interfaceType)} must be {true}.

IsValidImplementation(type, implementedType):

   1. If {implementedType} declares it implements any interfaces,
      {type} must also declare it implements those interfaces.
   2. {type} must include a field of the same name for every field
      defined in {implementedType}.
      1. Let {field} be that named field on {type}.
      2. Let {implementedField} be that named field on {implementedType}.
      3. {field} must include an argument of the same name for every argument
         defined in {implementedField}.
         1. That named argument on {field} must accept the same type
            (invariant) as that named argument on {implementedField}.
      4. {field} may include additional arguments not defined in
         {implementedField}, but any additional argument must not be required,
         e.g. must not be of a non-nullable type.
      5. {field} must return a type which is equal to or a sub-type of
         (covariant) the return type of {implementedField} field's return type:
         1. Let {fieldType} be the return type of {field}.
         2. Let {implementedFieldType} be the return type of {implementedField}.
         3. {IsValidImplementationFieldType(fieldType, implementedFieldType)}
            must be {true}.

IsValidImplementationFieldType(fieldType, implementedFieldType):
  1. If {fieldType} is a *Non-Null type*:
     1. Let {nullableType} be the *nullable type* of {fieldType}.
     2. Let {implementedNullableType} be the *nullable type*
        of {implementedFieldType} if it is a *Non-Null type*, otherwise let it
        be {implementedFieldType} directly.
     3. Return {IsValidImplementationFieldType(nullableType, implementedNullableType)}.
  2. If {fieldType} is and {implementedFieldType} are both a *List type*:
     1. Let {itemType} be the *item type* of {fieldType}.
     2. Let {implementedItemType} be the *item type* of {implementedFieldType}.
     3. Return {IsValidImplementationFieldType(itemType, implementedItemType)}.
  3. If {fieldType} is the same type as {implementedFieldType} then return {true}.
  4. If {fieldType} is an *Object type* and {implementedFieldType} is
     a *Union type* and {fieldType} is a possible type of {implementedFieldType}
     then return {true}.
  5. If {fieldType} is an *Object type* or *Interface type* and
     {implementedFieldType} is an *Interface type* and {fieldType} declares it
     implements {implementedFieldType} then return {true}.
  6. Otherwise return {false}.


### Field Arguments

ArgumentsDefinition : ( InputValueDefinition+ )

InputValueDefinition : Description? Name : Type DefaultValue? Directives[Const]?

Object fields are conceptually functions which yield values. Occasionally object
fields can accept arguments to further specify the return value. Object field
arguments are defined as a list of all possible argument names and each of their
expected *input type*.

All arguments defined within a field must not have a name which begins with
{"__"} (two underscores), as this is used exclusively by GraphQL's
introspection system.

For example, a `Person` type with a `picture` field could accept an argument to
determine what size of an image to return.

```graphql example
type Person {
  name: String
  picture(size: Int): Url
}
```

Operations can optionally specify arguments to their fields to provide
these arguments.

This example operation:

```graphql example
{
  name
  picture(size: 600)
}
```

May return the result:

```json example
{
  "name": "Mark Zuckerberg",
  "picture": "http://some.cdn/picture_600.jpg"
}
```

The type of an object field argument must be an *input type*.


### Field Deprecation

Fields in an object may be marked as deprecated as deemed necessary by the
application. It is still legal to include these fields in a selection set
(to ensure existing clients are not broken by the change), but the fields should
be appropriately treated in documentation and tooling.

When using the type system definition language, `@deprecated` directives are
used to indicate that a field is deprecated:

```graphql example
type ExampleType {
  oldField: String @deprecated
}
```


### Object Extensions

ObjectTypeExtension :
  - extend type Name ImplementsInterfaces? Directives[Const]? FieldsDefinition
  - extend type Name ImplementsInterfaces? Directives[Const] [lookahead != `{`]
  - extend type Name ImplementsInterfaces [lookahead != `{`]

Object type extensions are used to represent a type which has been extended from
some original type. For example, this might be used to represent local data, or
by a GraphQL service which is itself an extension of another GraphQL service.

In this example, a local data field is added to a `Story` type:

```graphql example
extend type Story {
  isHiddenLocally: Boolean
}
```

Object type extensions may choose not to add additional fields, instead only
adding interfaces or directives.

In this example, a directive is added to a `User` type without adding fields:

```graphql example
extend type User @addedDirective
```

**Type Validation**

Object type extensions have the potential to be invalid if incorrectly defined.

1. The named type must already be defined and must be an Object type.
2. The fields of an Object type extension must have unique names; no two fields
   may share the same name.
3. Any fields of an Object type extension must not be already defined on the
   original Object type.
4. Any non-repeatable directives provided must not already apply to the
   original Object type.
5. Any interfaces provided must not be already implemented by the original
   Object type.
6. The resulting extended object type must be a super-set of all interfaces it
   implements.


## Interfaces

InterfaceTypeDefinition :
  - Description? interface Name ImplementsInterfaces? Directives[Const]? FieldsDefinition
  - Description? interface Name ImplementsInterfaces? Directives[Const]? [lookahead != `{`]

:: An *Interface type* represents a list of named fields and their arguments.
An *object type* or another *interface type* can implement an interface which
requires that it defines all fields defined by that interface.

Fields on a GraphQL interface have the same rules as fields on a GraphQL object;
their type must be an *output type*.

For example, an interface `NamedEntity` may describe a required field and types
such as `Person` or `Business` may then implement this interface to guarantee
this field will always exist.

Types may also implement multiple interfaces. For example, `Business` implements
both the `NamedEntity` and `ValuedEntity` interfaces in the example below.

```graphql example
interface NamedEntity {
  name: String
}

interface ValuedEntity {
  value: Int
}

type Person implements NamedEntity {
  name: String
  age: Int
}

type Business implements NamedEntity & ValuedEntity {
  name: String
  value: Int
  employeeCount: Int
}
```

Fields which yield an interface are useful when one of many Object types are
expected, but some fields should be guaranteed.

To continue the example, a `Contact` might refer to `NamedEntity`.

```graphql example
type Contact {
  entity: NamedEntity
  phoneNumber: String
  address: String
}
```

This allows us to write a selection set for a `Contact` that can select the
common fields.

```graphql example
{
  entity {
    name
  }
  phoneNumber
}
```

When selecting fields on an interface type, only those fields declared on
the interface may be queried. In the above example, `entity` returns a
`NamedEntity`, and `name` is defined on `NamedEntity`, so it is valid. However,
the following would not be a valid selection set against `Contact`:

```graphql counter-example
{
  entity {
    name
    age
  }
  phoneNumber
}
```

because `entity` refers to a `NamedEntity`, and `age` is not defined on that
interface. Querying for `age` is only valid when the result of `entity` is a
`Person`; this can be expressed using a fragment or an inline fragment:

```graphql example
{
  entity {
    name
    ... on Person {
      age
    }
  }
  phoneNumber
}
```

**Interfaces Implementing Interfaces**

When defining an interface that implements another interface, the implementing
interface must define each field that is specified by the implemented interface.
For example, the interface Resource must define the field id to implement the
Node interface:

```raw graphql example
interface Node {
  id: ID!
}

interface Resource implements Node {
  id: ID!
  url: String
}
```

Transitively implemented interfaces (interfaces implemented by the interface
that is being implemented) must also be defined on an implementing type or
interface. For example, `Image` cannot implement `Resource` without also
implementing `Node`:

```raw graphql example
interface Node {
  id: ID!
}

interface Resource implements Node {
  id: ID!
  url: String
}

interface Image implements Resource & Node {
  id: ID!
  url: String
  thumbnail: String
}
```

Interface definitions must not contain cyclic references nor implement
themselves. This example is invalid because `Node` and `Named` implement
themselves and each other:

```graphql counter-example
interface Node implements Named & Node {
  id: ID!
  name: String
}

interface Named implements Node & Named {
  id: ID!
  name: String
}
```


**Result Coercion**

The interface type should have some way of determining which object a given
result corresponds to. Once it has done so, the result coercion of the interface
is the same as the result coercion of the object.

**Input Coercion**

Interfaces are never valid inputs.

**Type Validation**

Interface types have the potential to be invalid if incorrectly defined.

1. An Interface type must define one or more fields.
2. For each field of an Interface type:
   1. The field must have a unique name within that Interface type;
      no two fields may share the same name.
   2. The field must not have a name which begins with the
      characters {"__"} (two underscores).
   3. The field must return a type where {IsOutputType(fieldType)}
      returns {true}.
   4. For each argument of the field:
      1. The argument must not have a name which begins with the
         characters {"__"} (two underscores).
      2. The argument must accept a type where {IsInputType(argumentType)}
         returns {true}.
3. An interface type may declare that it implements one or more unique
   interfaces, but may not implement itself.
4. An interface type must be a super-set of all interfaces it implements:
   1. Let this interface type be {implementingType}.
   2. For each interface declared implemented as {implementedType},
      {IsValidImplementation(implementingType, implementedType)} must be {true}.


### Interface Extensions

InterfaceTypeExtension :
  - extend interface Name ImplementsInterfaces? Directives[Const]? FieldsDefinition
  - extend interface Name ImplementsInterfaces? Directives[Const] [lookahead != `{`]
  - extend interface Name ImplementsInterfaces [lookahead != `{`]

Interface type extensions are used to represent an interface which has been
extended from some original interface. For example, this might be used to
represent common local data on many types, or by a GraphQL service which is
itself an extension of another GraphQL service.

In this example, an extended data field is added to a `NamedEntity` type along
with the types which implement it:

```graphql example
extend interface NamedEntity {
  nickname: String
}

extend type Person {
  nickname: String
}

extend type Business {
  nickname: String
}
```

Interface type extensions may choose not to add additional fields, instead only
adding directives.

In this example, a directive is added to a `NamedEntity` type without
adding fields:

```graphql example
extend interface NamedEntity @addedDirective
```

**Type Validation**

Interface type extensions have the potential to be invalid if incorrectly defined.

1. The named type must already be defined and must be an Interface type.
2. The fields of an Interface type extension must have unique names; no two
   fields may share the same name.
3. Any fields of an Interface type extension must not be already defined on the
   original Interface type.
4. Any Object or Interface type which implemented the original Interface type
   must also be a super-set of the fields of the Interface type extension (which
   may be due to Object type extension).
5. Any non-repeatable directives provided must not already apply to the
   original Interface type.
6. The resulting extended Interface type must be a super-set of all Interfaces
   it implements.


## Unions

UnionTypeDefinition : Description? union Name Directives[Const]? UnionMemberTypes?

UnionMemberTypes :
  - UnionMemberTypes | NamedType
  - = `|`? NamedType

:: A *Union type* represents an value that could be one of a list of potential
*Object type*, but provides for no guaranteed fields between those types.
They also differ from interfaces in that Object types declare what interfaces
they implement, but are not aware of what unions contain them.

With interfaces and objects, only those fields defined on the type can be
queried directly; to query other fields on an interface, typed fragments
must be used. This is the same as for unions, but unions do not define any
fields, so **no** fields may be queried on this type without the use of
type refining fragments or inline fragments (with the exception of the
meta-field {__typename}).

For example, we might define the following types:

```graphql example
union SearchResult = Photo | Person

type Person {
  name: String
  age: Int
}

type Photo {
  height: Int
  width: Int
}

type SearchQuery {
  firstSearchResult: SearchResult
}
```

In this example, a query operation wants the name if the result was a Person,
and the height if it was a photo. However because a union itself defines no
fields, this could be ambiguous and is invalid.

```graphql counter-example
{
  firstSearchResult {
    name
    height
  }
}
```

A valid operation includes typed fragments (in this example, inline fragments):

```graphql example
{
  firstSearchResult {
    ... on Person {
      name
    }
    ... on Photo {
      height
    }
  }
}
```

Union members may be defined with an optional leading `|` character to aid
formatting when representing a longer list of possible types:

```raw graphql example
union SearchResult =
  | Photo
  | Person
```

**Result Coercion**

The union type should have some way of determining which object a given result
corresponds to. Once it has done so, the result coercion of the union is the
same as the result coercion of the object.

**Input Coercion**

Unions are never valid inputs.

**Type Validation**

Union types have the potential to be invalid if incorrectly defined.

1. A Union type must include one or more unique member types.
2. The member types of a Union type must each be an *Object type*;
   Scalar, Interface and Union types must not be member types of a Union.
   Similarly, *wrapped types* must not be member types of a Union.


### Union Extensions

UnionTypeExtension :
  - extend union Name Directives[Const]? UnionMemberTypes
  - extend union Name Directives[Const]

Union type extensions are used to represent a union type which has been
extended from some original union type. For example, this might be used to
represent additional local data, or by a GraphQL service which is itself an
extension of another GraphQL service.

**Type Validation**

Union type extensions have the potential to be invalid if incorrectly defined.

1. The named type must already be defined and must be a Union type.
2. The member types of a Union type extension must each be an *Object type*;
   Scalar, Interface and Union types must not be member types of a Union.
   Similarly, *wrapped types* must not be member types of a Union.
3. All member types of a Union type extension must be unique.
4. All member types of a Union type extension must not already be a member of
   the original Union type.
5. Any non-repeatable directives provided must not already apply to the
   original Union type.

## Enums

EnumTypeDefinition :
  - Description? enum Name Directives[Const]? EnumValuesDefinition
  - Description? enum Name Directives[Const]? [lookahead != `{`]

EnumValuesDefinition : { EnumValueDefinition+ }

EnumValueDefinition : Description? EnumValue Directives[Const]?

:: An *Enum type*, like a *Scalar type*, is a *leaf type* representing leaf
values in a GraphQL response or input. However Enum types describe the set of
possible values.

Enums are not references for a numeric value, but are unique values in their own
right. They may serialize as a string: the name of the represented value.

In this example, an Enum type called `Direction` is defined:

```graphql example
enum Direction {
  NORTH
  EAST
  SOUTH
  WEST
}
```

**Result Coercion**

GraphQL services must return one of the defined set of possible values. If a
reasonable coercion is not possible they must raise a field error.

**Input Coercion**

GraphQL has a constant literal to represent enum input values. GraphQL string
literals must not be accepted as an enum input and instead raise a request error.

Variable transport serializations which have a different representation
for non-string symbolic values (for example, [EDN](https://github.com/edn-format/edn))
should only allow such values as enum input values. Otherwise, for most
transport serializations that do not, strings may be interpreted as the enum
input value with the same name.

**Type Validation**

Enum types have the potential to be invalid if incorrectly defined.

1. An Enum type must define one or more unique enum values.


### Enum Extensions

EnumTypeExtension :
  - extend enum Name Directives[Const]? EnumValuesDefinition
  - extend enum Name Directives[Const] [lookahead != `{`]

Enum type extensions are used to represent an enum type which has been
extended from some original enum type. For example, this might be used to
represent additional local data, or by a GraphQL service which is itself an
extension of another GraphQL service.

**Type Validation**

Enum type extensions have the potential to be invalid if incorrectly defined.

1. The named type must already be defined and must be an Enum type.
2. All values of an Enum type extension must be unique.
3. All values of an Enum type extension must not already be a value of
   the original Enum.
4. Any non-repeatable directives provided must not already apply to the
   original Enum type.


## Input Objects

InputObjectTypeDefinition :
  - Description? input Name Directives[Const]? InputFieldsDefinition
  - Description? input Name Directives[Const]? [lookahead != `{`]

InputFieldsDefinition : { InputValueDefinition+ }

Fields may accept arguments to configure their behavior. These inputs are often
scalars or enums, but they sometimes need to represent more complex values.

:: An *Input Object type* defines a set of input fields; the input fields are
any *input type* (Scalars, Enums, or Input Objects). This allows arguments to
accept arbitrarily complex data.

In this example, an Input Object called `Point2D` describes `x` and `y` inputs:

```graphql example
input Point2D {
  x: Float
  y: Float
}
```

Note: The GraphQL Object type ({ObjectTypeDefinition}) defined above is
inappropriate for re-use here, because Object types can contain fields that
define arguments or contain references to interfaces and unions, neither of
which is appropriate for use as an input argument. For this reason, input
objects have a separate type in the system.

**Circular References**

Input Objects are allowed to reference other Input Objects as field types. A
circular reference occurs when an Input Object references itself either directly
or through referenced Input Objects.

Circular references are generally allowed, however they may not be defined as an
unbroken chain of Non-Null singular fields. Such Input Objects are invalid
because there is no way to provide a legal value for them.

This example of a circularly-referenced input type is valid as the field `self`
may be omitted or the value {null}.

```graphql example
input Example {
  self: Example
  value: String
}
```

This example is also valid as the field `self` may be an empty List.

```graphql example
input Example {
  self: [Example!]!
  value: String
}
```

This example of a circularly-referenced input type is invalid as the field
`self` cannot be provided a finite value.

```graphql counter-example
input Example {
  value: String
  self: Example!
}
```

This example is also invalid, as there is a non-null singular circular reference
via the `First.second` and `Second.first` fields.

```graphql counter-example
input First {
  second: Second!
  value: String
}

input Second {
  first: First!
  value: String
}
```

**Result Coercion**

An input object is never a valid result. Input Object types cannot be the return
type of an Object or Interface field.

**Input Coercion**

The value for an input object should be an input object literal or an unordered
map supplied by a variable, otherwise a request error must be raised. In either
case, the input object literal or unordered map must not contain any entries
with names not defined by a field of this input object type, otherwise a
response error must be raised.

The result of coercion is an unordered map with an entry for each field both
defined by the input object type and for which a value exists. The resulting map
is constructed with the following rules:

* If no value is provided for a defined input object field and that field
  definition provides a default value, the default value should be used. If no
  default value is provided and the input object field's type is non-null, an
  error should be raised. Otherwise, if the field is not required, then no entry
  is added to the coerced unordered map.

* If the value {null} was provided for an input object field, and the field's
  type is not a non-null type, an entry in the coerced unordered map is given
  the value {null}. In other words, there is a semantic difference between the
  explicitly provided value {null} versus having not provided a value.

* If a literal value is provided for an input object field, an entry in the
  coerced unordered map is given the result of coercing that value according
  to the input coercion rules for the type of that field.

* If a variable is provided for an input object field, the runtime value of that
  variable must be used. If the runtime value is {null} and the field type
  is non-null, a field error must be raised. If no runtime value is provided,
  the variable definition's default value should be used. If the variable
  definition does not provide a default value, the input object field
  definition's default value should be used.

Following are examples of input coercion for an input object type with a
`String` field `a` and a required (non-null) `Int!` field `b`:

```graphql example
input ExampleInputObject {
  a: String
  b: Int!
}
```

Literal Value            | Variables               | Coerced Value
------------------------ | ----------------------- | ---------------------------
`{ a: "abc", b: 123 }`   | `{}`                    | `{ a: "abc", b: 123 }`
`{ a: null, b: 123 }`    | `{}`                    | `{ a: null, b: 123 }`
`{ b: 123 }`             | `{}`                    | `{ b: 123 }`
`{ a: $var, b: 123 }`    | `{ var: null }`         | `{ a: null, b: 123 }`
`{ a: $var, b: 123 }`    | `{}`                    | `{ b: 123 }`
`{ b: $var }`            | `{ var: 123 }`          | `{ b: 123 }`
`$var`                   | `{ var: { b: 123 } }`   | `{ b: 123 }`
`"abc123"`               | `{}`                    | Error: Incorrect value
`$var`                   | `{ var: "abc123" }`     | Error: Incorrect value
`{ a: "abc", b: "123" }` | `{}`                    | Error: Incorrect value for field {b}
`{ a: "abc" }`           | `{}`                    | Error: Missing required field {b}
`{ b: $var }`            | `{}`                    | Error: Missing required field {b}.
`$var`                   | `{ var: { a: "abc" } }` | Error: Missing required field {b}
`{ a: "abc", b: null }`  | `{}`                    | Error: {b} must be non-null.
`{ b: $var }`            | `{ var: null }`         | Error: {b} must be non-null.
`{ b: 123, c: "xyz" }`   | `{}`                    | Error: Unexpected field {c}

**Type Validation**

1. An Input Object type must define one or more input fields.
2. For each input field of an Input Object type:
   1. The input field must have a unique name within that Input Object type;
      no two input fields may share the same name.
   2. The input field must not have a name which begins with the
      characters {"__"} (two underscores).
   3. The input field must accept a type where {IsInputType(inputFieldType)}
      returns {true}.
3. If an Input Object references itself either directly or through referenced
   Input Objects, at least one of the fields in the chain of references must be
   either a nullable or a List type.


### Input Object Extensions

InputObjectTypeExtension :
  - extend input Name Directives[Const]? InputFieldsDefinition
  - extend input Name Directives[Const] [lookahead != `{`]

Input Object type extensions are used to represent an *Input Object type* which
has been extended from some original Input Object type. For example, this might
be used by a GraphQL service which is itself an extension of another GraphQL
service.

**Type Validation**

Input Object type extensions have the potential to be invalid if incorrectly defined.

1. The named type must already be defined and must be a Input Object type.
2. All fields of an Input Object type extension must have unique names.
3. All fields of an Input Object type extension must not already be a field of
   the original Input Object.
4. Any non-repeatable directives provided must not already apply to the
   original Input Object type.


## List

:: By default, all types in GraphQL are singular. A *List type* is a
*wrapped type* which defines an ordered collection of its *inner type*.

:: Each instance of a List type wraps a *item type*, its *inner type*,
describing the type of each item in the List. List values are serialized as
ordered lists, where each item in the list is serialized as per the item type.
An *item type* field may itself be a *wrapped type*, allowing the representation
of Lists of Lists, or Lists of Non-Nulls.

To denote that a type is a *List type* the *item type* is wrapped in square
brackets like this: `pets: [Pet]`. Nesting lists is allowed: `matrix: [[Int]]`.

**Result Coercion**

GraphQL services must return an ordered list as the result of a list type. Each
item in the list must be the result of a result coercion of the item type. If a
reasonable coercion is not possible it must raise a field error. In
particular, if a non-list is returned, the coercion should fail, as this
indicates a mismatch in expectations between the type system and the
implementation.

If a list's item type is nullable, then errors occurring during preparation or
coercion of an individual item in the list must result in a the value {null} at
that position in the list along with a field error added to the response.
If a list's item type is non-null, a field error occurring at an individual item
in the list must result in a field error for the entire list.

Note: See [Handling Field Errors](#sec-Handling-Field-Errors) for more about
this behavior.

**Input Coercion**

When expected as an input, list values are accepted only when each item in the
list can be accepted by the list's item type.

If the value passed as an input to a list type is *not* a list and not the
{null} value, then the result of input coercion is a list of size one,
where the single item value is the result of input coercion for the list's item
type on the provided value (note this may apply recursively for nested lists).

This allows inputs which accept one or many arguments (sometimes referred to as
"var args") to declare their input type as a list while for the common case of a
single value, a client can just pass that value directly rather than
constructing the list.

Following are examples of input coercion with various list types and values:

Expected Type | Provided Value   | Coerced Value
------------- | ---------------- | ---------------------------
`[Int]`       | `[1, 2, 3]`      | `[1, 2, 3]`
`[Int]`       | `[1, "b", true]` | Error: Incorrect item value
`[Int]`       | `1`              | `[1]`
`[Int]`       | `null`           | `null`
`[[Int]]`     | `[[1], [2, 3]]`  | `[[1], [2, 3]]`
`[[Int]]`     | `[1, 2, 3]`      | Error: Incorrect item value
`[[Int]]`     | `1`              | `[[1]]`
`[[Int]]`     | `null`           | `null`


## Non-Null

:: By default, all types in GraphQL are nullable; the {null} value is a valid
response for all of the above types. A *Non-Null type* is a *wrapped type* which
defines a variation of its *inner type* which must not be {null}.

:: Each instance of a Non-Null type has a *nullable type*, its *inner type*.
The Non-Null type acts identically to its nullable type, with the exception that
{null} is not a valid response. A *nullable type* field may be a *List type*,
allowing the representation of Non-Null of Lists. However it must not be another
*Non-Null type* to avoid a redundant Non-Null of Non-Null.

To denote that a type is a *Non-Null type* the *nullable type* is followed by an
exclamation mark like this: `required: String!`.

**Nullable vs. Optional**

Fields are *always* optional within the context of a selection set, a field may
be omitted and the selection set is still valid. However fields that return
Non-Null types will never return the value {null} if queried.

Inputs (such as field arguments), are always optional by default. However a
non-null input type is required. In addition to not accepting the value {null},
it also does not accept omission. For the sake of simplicity nullable types
are always optional and non-null types are always required.

**Result Coercion**

In all of the above result coercions, {null} was considered a valid value.
To coerce the result of a Non-Null type, the coercion of the *inner type*
should be performed. If that result was not {null}, then the result of coercing
the Non-Null type is that result. If that result was {null}, then a field error
must be raised.

Note: When a field error is raised on a non-null value, the error propagates to
the parent field. For more information on this process, see
"Errors and Non-Nullability" within the Execution section.

**Input Coercion**

If an argument or input-object field of a Non-Null type is not provided, is
provided with the literal value {null}, or is provided with a variable that was
either not provided a value at runtime, or was provided the value {null}, then
a request error must be raised.

If the value provided to the Non-Null type is provided with a literal value
other than {null}, or a Non-Null variable value, it is coerced using the input
coercion for the *inner type*.

A non-null argument cannot be omitted:

```graphql counter-example
{
  fieldWithNonNullArg
}
```

The value {null} cannot be provided to a non-null argument:

```graphql counter-example
{
  fieldWithNonNullArg(nonNullArg: null)
}
```

A variable of a nullable type cannot be provided to a non-null argument:

```graphql example
query withNullableVariable($var: String) {
  fieldWithNonNullArg(nonNullArg: $var)
}
```

Note: The Validation section defines providing a nullable variable type to
a non-null input type as invalid.

**Type Validation**

1. A *Non-Null type* must not wrap another *Non-Null type*.


### Combining List and Non-Null

The *List type* and *Non-Null types* can compose, representing more complex
types. The rules for result coercion and input coercion of List and Non-Null
types apply in a recursive fashion.

For example if the *item type* of a *List type* is a *Non-Null type*
(e.g. `[T!]`), then that List value may not contain any {null} items. However if
the *nullable type* of a *Non-Null type* is a *List type* (e.g. `[T]!`), then
{null} is not accepted as a value, however a List containing {null} as an item
is accepted.

Following are examples of result coercion with various types and values:

Expected Type | Internal Value   | Coerced Result
------------- | ---------------- | ---------------------------
`[Int]`       | `[1, 2, 3]`      | `[1, 2, 3]`
`[Int]`       | `null`           | `null`
`[Int]`       | `[1, 2, null]`   | `[1, 2, null]`
`[Int]`       | `[1, 2, Error]`  | `[1, 2, null]` (With logged error)
`[Int]!`      | `[1, 2, 3]`      | `[1, 2, 3]`
`[Int]!`      | `null`           | Error: Value cannot be null
`[Int]!`      | `[1, 2, null]`   | `[1, 2, null]`
`[Int]!`      | `[1, 2, Error]`  | `[1, 2, null]` (With logged error)
`[Int!]`      | `[1, 2, 3]`      | `[1, 2, 3]`
`[Int!]`      | `null`           | `null`
`[Int!]`      | `[1, 2, null]`   | `null` (With logged coercion error)
`[Int!]`      | `[1, 2, Error]`  | `null` (With logged error)
`[Int!]!`     | `[1, 2, 3]`      | `[1, 2, 3]`
`[Int!]!`     | `null`           | Error: Value cannot be null
`[Int!]!`     | `[1, 2, null]`   | Error: Item cannot be null
`[Int!]!`     | `[1, 2, Error]`  | Error: Error occurred in item


## Directives

DirectiveDefinition : Description? directive @ Name ArgumentsDefinition? `repeatable`? on DirectiveLocations

DirectiveLocations :
  - DirectiveLocations | DirectiveLocation
  - `|`? DirectiveLocation

DirectiveLocation :
  - ExecutableDirectiveLocation
  - TypeSystemDirectiveLocation

ExecutableDirectiveLocation : one of
  - `QUERY`
  - `MUTATION`
  - `SUBSCRIPTION`
  - `FIELD`
  - `FRAGMENT_DEFINITION`
  - `FRAGMENT_SPREAD`
  - `INLINE_FRAGMENT`
  - `VARIABLE_DEFINITION`

TypeSystemDirectiveLocation : one of
  - `SCHEMA`
  - `SCALAR`
  - `OBJECT`
  - `FIELD_DEFINITION`
  - `ARGUMENT_DEFINITION`
  - `INTERFACE`
  - `UNION`
  - `ENUM`
  - `ENUM_VALUE`
  - `INPUT_OBJECT`
  - `INPUT_FIELD_DEFINITION`

A GraphQL schema describes directives which are used to annotate various parts
of a GraphQL document as an indicator that they should be evaluated differently
by a validator, executor, or client tool such as a code generator.

**Built-in Directives**

:: A *built-in directive* is any directive defined within this specification.

GraphQL implementations should provide the `@skip` and `@include` directives.

GraphQL implementations that support the type system definition language must
provide the `@deprecated` directive if representing deprecated portions of
the schema.

GraphQL implementations that support the type system definition language should
provide the `@specifiedBy` directive if representing *custom scalar type*
definitions.

When representing a GraphQL schema using the type system definition language
any *built-in directive* may be omitted for brevity.

When introspecting a GraphQL service all provided directives, including
any *built-in directive*, must be included in the set of returned directives.

**Custom Directives**

:: GraphQL services and client tooling may provide any additional
*custom directive* beyond those defined in this document. Directives are the
preferred way to extend GraphQL with custom or experimental behavior.

Note: When defining a *custom directive*, it is recommended to prefix the
directive's name to make its scope of usage clear and to prevent a collision
with *built-in directive* which may be specified by future versions of this
document (which will not include `_` in their name). For example, a
*custom directive* used by Facebook's GraphQL service should be named `@fb_auth`
instead of `@auth`. This is especially recommended for proposed additions to
this specification which can change during the [RFC process](https://github.com/graphql/graphql-spec/blob/main/CONTRIBUTING.md).
For example a work in progress version of `@live` should be named `@rfc_live`.

Directives must only be used in the locations they are declared to belong in.
In this example, a directive is defined which can be used to annotate a field:

```graphql example
directive @example on FIELD

fragment SomeFragment on SomeType {
  field @example
}
```

Directive locations may be defined with an optional leading `|` character to aid
formatting when representing a longer list of possible locations:

```raw graphql example
directive @example on
  | FIELD
  | FRAGMENT_SPREAD
  | INLINE_FRAGMENT
```

Directives can also be used to annotate the type system definition language
as well, which can be a useful tool for supplying additional metadata in order
to generate GraphQL execution services, produce client generated runtime code,
or many other useful extensions of the GraphQL semantics.

In this example, the directive `@example` annotates field and argument definitions:

```graphql example
directive @example on FIELD_DEFINITION | ARGUMENT_DEFINITION

type SomeType {
  field(arg: Int @example): String @example
}
```

A directive may be defined as repeatable by including the "repeatable" keyword.
Repeatable directives are often useful when the same directive should be used
with different arguments at a single location, especially in cases where
additional information needs to be provided to a type or schema extension via
a directive:

```graphql example
directive @delegateField(name: String!) repeatable on OBJECT | INTERFACE

type Book @delegateField(name: "pageCount") @delegateField(name: "author") {
  id: ID!
}

extend type Book @delegateField(name: "index")
```

While defining a directive, it must not reference itself directly or indirectly:

```graphql counter-example
directive @invalidExample(arg: String @invalidExample) on ARGUMENT_DEFINITION
```

Note: The order in which directives appear may be significant, including
repeatable directives.

**Validation**

1. A directive definition must not contain the use of a directive which
   references itself directly.
2. A directive definition must not contain the use of a directive which
   references itself indirectly by referencing a Type or Directive which
   transitively includes a reference to this directive.
3. The directive must not have a name which begins with the characters
   {"__"} (two underscores).
4. For each argument of the directive:
   1. The argument must not have a name which begins with the
      characters {"__"} (two underscores).
   2. The argument must accept a type where {IsInputType(argumentType)}
      returns {true}.

### @skip

```graphql
directive @skip(if: Boolean!) on FIELD | FRAGMENT_SPREAD | INLINE_FRAGMENT
```

The `@skip` *built-in directive* may be provided for fields, fragment spreads,
and inline fragments, and allows for conditional exclusion during execution as
described by the `if` argument.

In this example `experimentalField` will only be queried if the variable
`$someTest` has the value `false`.

```graphql example
query myQuery($someTest: Boolean!) {
  experimentalField @skip(if: $someTest)
}
```


### @include

```graphql
directive @include(if: Boolean!) on FIELD | FRAGMENT_SPREAD | INLINE_FRAGMENT
```

The `@include` *built-in directive* may be provided for fields, fragment
spreads, and inline fragments, and allows for conditional inclusion during
execution as described by the `if` argument.

In this example `experimentalField` will only be queried if the variable
`$someTest` has the value `true`

```graphql example
query myQuery($someTest: Boolean!) {
  experimentalField @include(if: $someTest)
}
```

Note: Neither `@skip` nor `@include` has precedence over the other. In the case
that both the `@skip` and `@include` directives are provided on the same
field or fragment, it *must* be queried only if the `@skip` condition is false
*and* the `@include` condition is true. Stated conversely, the field or fragment
must *not* be queried if either the `@skip` condition is true *or* the
`@include` condition is false.


### @deprecated

```graphql
directive @deprecated(
  reason: String = "No longer supported"
) on FIELD_DEFINITION | ENUM_VALUE
```

The `@deprecated` *built-in directive* is used within the type system definition
language to indicate deprecated portions of a GraphQL service's schema, such as
deprecated fields on a type or deprecated enum values.

Deprecations include a reason for why it is deprecated, which is formatted using
Markdown syntax (as specified by [CommonMark](https://commonmark.org/)).

In this example type definition, `oldField` is deprecated in favor of
using `newField`.

```graphql example
type ExampleType {
  newField: String
  oldField: String @deprecated(reason: "Use `newField`.")
}
```


### @specifiedBy

```graphql
directive @specifiedBy(url: String!) on SCALAR
```

The `@specifiedBy` *built-in directive* is used within the type system
definition language to provide a *scalar specification URL* for specifying the
behavior of a *custom scalar type*. The URL should point to a human-readable
specification of the data format, serialization, and coercion rules. It must not
appear on *built-in scalars*.

In this example, a custom scalar `UUID` is defined by including a URL for the
relevant IETF specification for UUID.

```graphql example
scalar UUID @specifiedBy(url: "https://tools.ietf.org/html/rfc4122")
```
