# Language

Clients use the GraphQL query language to make requests to a GraphQL service.
We refer to these request sources as documents. A document may contain
operations (queries, mutations, and subscriptions) as well as fragments, a
common unit of composition allowing for data requirement reuse.

A GraphQL document is defined as a syntactic grammar where terminal symbols are
tokens (indivisible lexical units). These tokens are defined in a lexical
grammar which matches patterns of source characters. In this document, syntactic
grammar productions are distinguished with a colon `:` while lexical grammar
productions are distinguished with a double-colon `::`.

The source text of a GraphQL document must be a sequence of {SourceCharacter}.
The character sequence must be described by a sequence of {Token} and {Ignored}
lexical grammars. The lexical token sequence, omitting {Ignored}, must be
described by a single {Document} syntactic grammar.

Note: See [Appendix A](#sec-Appendix-Notation-Conventions) for more information
about the lexical and syntactic grammar and other notational conventions used
throughout this document.

**Lexical Analysis & Syntactic Parse**

The source text of a GraphQL document is first converted into a sequence of
lexical tokens, {Token}, and ignored tokens, {Ignored}. The source text is
scanned from left to right, repeatedly taking the next possible sequence of
code-points allowed by the lexical grammar productions as the next token. This
sequence of lexical tokens are then scanned from left to right to produce an
abstract syntax tree (AST) according to the {Document} syntactical grammar.

Lexical grammar productions in this document use *lookahead restrictions* to
remove ambiguity and ensure a single valid lexical analysis. A lexical token is
only valid if not followed by a character in its lookahead restriction.

For example, an {IntValue} has the restriction {[lookahead != Digit]}, so cannot
be followed by a {Digit}. Because of this, the sequence {`123`} cannot represent
the tokens ({`12`}, {`3`}) since {`12`} is followed by the {Digit} {`3`} and
so must only represent a single token. Use {WhiteSpace} or other {Ignored}
between characters to represent multiple tokens.

Note: This typically has the same behavior as a
"[maximal munch](https://en.wikipedia.org/wiki/Maximal_munch)" longest possible
match, however some lookahead restrictions include additional constraints.


## Source Text

SourceCharacter ::
  - "Any Unicode scalar value"

GraphQL documents are interpreted from a source text, which is a sequence of
{SourceCharacter}, each {SourceCharacter} being a *Unicode scalar value* which
may be any Unicode code point from U+0000 to U+D7FF or U+E000 to U+10FFFF
(informally referred to as *"characters"* through most of this specification).

A GraphQL document may be expressed only in the ASCII range to be as widely
compatible with as many existing tools, languages, and serialization formats as
possible and avoid display issues in text editors and source control. Non-ASCII
Unicode scalar values may appear within {StringValue} and {Comment}.

Note: An implementation which uses *UTF-16* to represent GraphQL documents in
memory (for example, JavaScript or Java) may encounter a *surrogate pair*. This
encodes a *supplementary code point* and is a single valid source character,
however an unpaired *surrogate code point* is not a valid source character.


### White Space

WhiteSpace ::
  - "Horizontal Tab (U+0009)"
  - "Space (U+0020)"

White space is used to improve legibility of source text and act as separation
between tokens, and any amount of white space may appear before or after any
token. White space between tokens is not significant to the semantic meaning of
a GraphQL Document, however white space characters may appear within a
{String} or {Comment} token.

Note: GraphQL intentionally does not consider Unicode "Zs" category characters
as white-space, avoiding misinterpretation by text editors and source
control tools.


### Line Terminators

LineTerminator ::
  - "New Line (U+000A)"
  - "Carriage Return (U+000D)" [lookahead != "New Line (U+000A)"]
  - "Carriage Return (U+000D)" "New Line (U+000A)"

Like white space, line terminators are used to improve the legibility of source
text and separate lexical tokens, any amount may appear before or after any
other token and have no significance to the semantic meaning of a GraphQL
Document. Line terminators are not found within any other token.

Note: Any error reporting which provides the line number in the source of the
offending syntax should use the preceding amount of {LineTerminator} to produce
the line number.


### Comments

Comment :: `#` CommentChar* [lookahead != CommentChar]

CommentChar :: SourceCharacter but not LineTerminator

GraphQL source documents may contain single-line comments, starting with the
{`#`} marker.

A comment can contain any Unicode code point in {SourceCharacter} except
{LineTerminator} so a comment always consists of all code points starting with
the {`#`} character up to but not including the {LineTerminator} (or end of
the source).

Comments are {Ignored} like white space and may appear after any token, or
before a {LineTerminator}, and have no significance to the semantic meaning of a
GraphQL Document.


### Insignificant Commas

Comma :: ,

Similar to white space and line terminators, commas ({`,`}) are used to improve
the legibility of source text and separate lexical tokens but are otherwise
syntactically and semantically insignificant within GraphQL Documents.

Non-significant comma characters ensure that the absence or presence of a comma
does not meaningfully alter the interpreted syntax of the document, as this can
be a common user-error in other languages. It also allows for the stylistic use
of either trailing commas or line terminators as list delimiters which are both
often desired for legibility and maintainability of source code.


### Lexical Tokens

Token ::
  - Punctuator
  - Name
  - IntValue
  - FloatValue
  - StringValue

A GraphQL document is comprised of several kinds of indivisible lexical tokens
defined here in a lexical grammar by patterns of source Unicode characters.
Lexical tokens may be separated by {Ignored} tokens.

Tokens are later used as terminal symbols in GraphQL syntactic grammar rules.


### Ignored Tokens

Ignored ::
  - UnicodeBOM
  - WhiteSpace
  - LineTerminator
  - Comment
  - Comma

{Ignored} tokens are used to improve readability and provide separation between
lexical tokens, but are otherwise insignificant and not referenced in
syntactical grammar productions.

Any amount of {Ignored} may appear before and after every lexical token. No
ignored regions of a source document are significant, however {SourceCharacter}
which appear in {Ignored} may also appear within a lexical {Token} in a
significant way, for example a {StringValue} may contain white space characters.
No {Ignored} may appear *within* a {Token}, for example no white space
characters are permitted between the characters defining a {FloatValue}.

**Byte order mark**

UnicodeBOM :: "Byte Order Mark (U+FEFF)"

The *Byte Order Mark* is a special Unicode code point which may appear at the
beginning of a file which programs may use to determine the fact that the text
stream is Unicode, and what specific encoding has been used.

As files are often concatenated, a *Byte Order Mark* may appear anywhere within
a GraphQL document and is {Ignored}.

### Punctuators

Punctuator :: one of ! $ & ( ) ... : = @ [ ] { | }

GraphQL documents include punctuation in order to describe structure. GraphQL
is a data description language and not a programming language, therefore GraphQL
lacks the punctuation often used to describe mathematical expressions.


### Names

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
  - `A` `B` `C` `D` `E` `F` `G` `H` `I` `J` `K` `L` `M`
  - `N` `O` `P` `Q` `R` `S` `T` `U` `V` `W` `X` `Y` `Z`
  - `a` `b` `c` `d` `e` `f` `g` `h` `i` `j` `k` `l` `m`
  - `n` `o` `p` `q` `r` `s` `t` `u` `v` `w` `x` `y` `z`

Digit :: one of
  - `0` `1` `2` `3` `4` `5` `6` `7` `8` `9`

GraphQL Documents are full of named things: operations, fields, arguments,
types, directives, fragments, and variables. All names must follow the same
grammatical form.

Names in GraphQL are case-sensitive. That is to say `name`, `Name`, and `NAME`
all refer to different names. Underscores are significant, which means
`other_name` and `othername` are two different names.

A {Name} must not be followed by a {NameContinue}. In other words, a {Name}
token is always the longest possible valid sequence. The source characters
{`a1`} cannot be interpreted as two tokens since {`a`} is followed by the {NameContinue} {`1`}.

Note: Names in GraphQL are limited to the Latin <acronym>ASCII</acronym> subset
of {SourceCharacter} in order to support interoperation with as many other
systems as possible.

**Reserved Names**

Any {Name} within a GraphQL type system must not start with two underscores
{"__"} unless it is part of the [introspection system](#sec-Introspection) as
defined by this specification.


## Document

Document : Definition+

Definition :
  - ExecutableDefinition
  - TypeSystemDefinitionOrExtension

ExecutableDocument : ExecutableDefinition+

ExecutableDefinition :
  - OperationDefinition
  - FragmentDefinition

A GraphQL Document describes a complete file or request string operated on
by a GraphQL service or client. A document contains multiple definitions, either
executable or representative of a GraphQL type system.

Documents are only executable by a GraphQL service if they are
{ExecutableDocument} and contain at least one {OperationDefinition}. A
Document which contains {TypeSystemDefinitionOrExtension} must not be executed;
GraphQL execution services which receive a Document containing these should
return a descriptive error.

GraphQL services which only seek to execute GraphQL requests and not construct
a new GraphQL schema may choose to only permit {ExecutableDocument}.

Documents which do not contain {OperationDefinition} or do contain
{TypeSystemDefinitionOrExtension} may still be parsed and validated to allow
client tools to represent many GraphQL uses which may appear across many
individual files.

If a Document contains only one operation, that operation may be unnamed. If
that operation is a query without variables or directives then it may also be
represented in the shorthand form, omitting both the {`query`} keyword as well
as the operation name. Otherwise, if a GraphQL Document contains multiple
operations, each operation must be named. When submitting a Document with
multiple operations to a GraphQL service, the name of the desired operation to
be executed must also be provided.


## Operations

OperationDefinition :
  - OperationType Name? VariableDefinitions? Directives? SelectionSet
  - SelectionSet

OperationType : one of `query` `mutation` `subscription`

There are three types of operations that GraphQL models:

  * query - a read-only fetch.
  * mutation - a write followed by a fetch.
  * subscription - a long-lived request that fetches data in response to source
    events.

Each operation is represented by an optional operation name and a selection set.

For example, this mutation operation might "like" a story and then retrieve the
new number of likes:

```graphql example
mutation {
  likeStory(storyID: 12345) {
    story {
      likeCount
    }
  }
}
```

**Query shorthand**

If a document contains only one operation and that operation is a query which
defines no variables and contains no directives then that operation may be
represented in a short-hand form which omits the {`query`} keyword and operation
name.

For example, this unnamed query operation is written via query shorthand.

```graphql example
{
  field
}
```

Note: many examples below will use the query short-hand syntax.


## Selection Sets

SelectionSet : { Selection+ }

Selection :
  - Field
  - FragmentSpread
  - InlineFragment

An operation selects the set of information it needs, and will receive exactly
that information and nothing more, avoiding over-fetching and
under-fetching data.

```graphql example
{
  id
  firstName
  lastName
}
```

In this query operation, the `id`, `firstName`, and `lastName` fields form a
selection set. Selection sets may also contain fragment references.


## Fields

Field : Alias? Name Arguments? Directives? SelectionSet?

A selection set is primarily composed of fields. A field describes one discrete
piece of information available to request within a selection set.

Some fields describe complex data or relationships to other data. In order to
further explore this data, a field may itself contain a selection set, allowing
for deeply nested requests. All GraphQL operations must specify their selections
down to fields which return scalar values to ensure an unambiguously
shaped response.

For example, this operation selects fields of complex data and relationships
down to scalar values.

```graphql example
{
  me {
    id
    firstName
    lastName
    birthday {
      month
      day
    }
    friends {
      name
    }
  }
}
```

Fields in the top-level selection set of an operation often represent some
information that is globally accessible to your application and its current
viewer. Some typical examples of these top fields include references to a
current logged-in viewer, or accessing certain types of data referenced by a
unique identifier.

```graphql example
# `me` could represent the currently logged in viewer.
{
  me {
    name
  }
}

# `user` represents one of many users in a graph of data, referred to by a
# unique identifier.
{
  user(id: 4) {
    name
  }
}
```


## Arguments

Arguments[Const] : ( Argument[?Const]+ )

Argument[Const] : Name : Value[?Const]

Fields are conceptually functions which return values, and occasionally accept
arguments which alter their behavior. These arguments often map directly to
function arguments within a GraphQL service's implementation.

In this example, we want to query a specific user (requested via the `id`
argument) and their profile picture of a specific `size`:

```graphql example
{
  user(id: 4) {
    id
    name
    profilePic(size: 100)
  }
}
```

Many arguments can exist for a given field:

```graphql example
{
  user(id: 4) {
    id
    name
    profilePic(width: 100, height: 50)
  }
}
```

**Arguments are unordered**

Arguments may be provided in any syntactic order and maintain identical
semantic meaning.

These two operations are semantically identical:

```graphql example
{
  picture(width: 200, height: 100)
}
```

```graphql example
{
  picture(height: 100, width: 200)
}
```


## Field Alias

Alias : Name :

By default a field's response key in the response object will use that field's
name. However, you can define a different response key by specifying an alias.

In this example, we can fetch two profile pictures of different sizes and ensure
the resulting response object will not have duplicate keys:

```graphql example
{
  user(id: 4) {
    id
    name
    smallPic: profilePic(size: 64)
    bigPic: profilePic(size: 1024)
  }
}
```

which returns the result:

```json example
{
  "user": {
    "id": 4,
    "name": "Mark Zuckerberg",
    "smallPic": "https://cdn.site.io/pic-4-64.jpg",
    "bigPic": "https://cdn.site.io/pic-4-1024.jpg"
  }
}
```

The fields at the top level of an operation can also be given an alias:

```graphql example
{
  zuck: user(id: 4) {
    id
    name
  }
}
```

which returns the result:

```json example
{
  "zuck": {
    "id": 4,
    "name": "Mark Zuckerberg"
  }
}
```


## Fragments

FragmentSpread : ... FragmentName Directives?

FragmentDefinition : fragment FragmentName TypeCondition Directives? SelectionSet

FragmentName : Name but not `on`

Fragments are the primary unit of composition in GraphQL.

Fragments allow for the reuse of common repeated selections of fields, reducing
duplicated text in the document. Inline Fragments can be used directly within a
selection to condition upon a type condition when querying against an interface
or union.

For example, if we wanted to fetch some common information about mutual friends
as well as friends of some user:

```graphql example
query noFragments {
  user(id: 4) {
    friends(first: 10) {
      id
      name
      profilePic(size: 50)
    }
    mutualFriends(first: 10) {
      id
      name
      profilePic(size: 50)
    }
  }
}
```

The repeated fields could be extracted into a fragment and composed by
a parent fragment or operation.

```graphql example
query withFragments {
  user(id: 4) {
    friends(first: 10) {
      ...friendFields
    }
    mutualFriends(first: 10) {
      ...friendFields
    }
  }
}

fragment friendFields on User {
  id
  name
  profilePic(size: 50)
}
```

Fragments are consumed by using the spread operator (`...`). All fields
selected by the fragment will be added to the field selection at the same level
as the fragment invocation. This happens through multiple levels of fragment
spreads.

For example:

```graphql example
query withNestedFragments {
  user(id: 4) {
    friends(first: 10) {
      ...friendFields
    }
    mutualFriends(first: 10) {
      ...friendFields
    }
  }
}

fragment friendFields on User {
  id
  name
  ...standardProfilePic
}

fragment standardProfilePic on User {
  profilePic(size: 50)
}
```

The operations `noFragments`, `withFragments`, and `withNestedFragments` all
produce the same response object.


### Type Conditions

TypeCondition : on NamedType

Fragments must specify the type they apply to. In this example, `friendFields`
can be used in the context of querying a `User`.

Fragments cannot be specified on any input value (scalar, enumeration, or input
object).

Fragments can be specified on object types, interfaces, and unions.

Selections within fragments only return values when the concrete type of the object
it is operating on matches the type of the fragment.

For example in this operation using the Facebook data model:

```graphql example
query FragmentTyping {
  profiles(handles: ["zuck", "coca-cola"]) {
    handle
    ...userFragment
    ...pageFragment
  }
}

fragment userFragment on User {
  friends {
    count
  }
}

fragment pageFragment on Page {
  likers {
    count
  }
}
```

The `profiles` root field returns a list where each element could be a `Page` or a
`User`. When the object in the `profiles` result is a `User`, `friends` will be
present and `likers` will not. Conversely when the result is a `Page`, `likers`
will be present and `friends` will not.

```json example
{
  "profiles": [
    {
      "handle": "zuck",
      "friends": { "count": 1234 }
    },
    {
      "handle": "coca-cola",
      "likers": { "count": 90234512 }
    }
  ]
}
```


### Inline Fragments

InlineFragment : ... TypeCondition? Directives? SelectionSet

Fragments can be defined inline within a selection set. This is done to
conditionally include fields based on their runtime type. This feature of
standard fragment inclusion was demonstrated in the `query FragmentTyping`
example. We could accomplish the same thing using inline fragments.

```graphql example
query inlineFragmentTyping {
  profiles(handles: ["zuck", "coca-cola"]) {
    handle
    ... on User {
      friends {
        count
      }
    }
    ... on Page {
      likers {
        count
      }
    }
  }
}
```

Inline fragments may also be used to apply a directive to a group of fields.
If the TypeCondition is omitted, an inline fragment is considered to be of the
same type as the enclosing context.

```graphql example
query inlineFragmentNoType($expandedInfo: Boolean) {
  user(handle: "zuck") {
    id
    name
    ... @include(if: $expandedInfo) {
      firstName
      lastName
      birthday
    }
  }
}
```


## Input Values

Value[Const] :
  - [~Const] Variable
  - IntValue
  - FloatValue
  - StringValue
  - BooleanValue
  - NullValue
  - EnumValue
  - ListValue[?Const]
  - ObjectValue[?Const]

Field and directive arguments accept input values of various literal primitives;
input values can be scalars, enumeration values, lists, or input objects.

If not defined as constant (for example, in {DefaultValue}), input values can be
specified as a variable. List and inputs objects may also contain variables (unless defined to be constant).


### Int Value

IntValue :: IntegerPart [lookahead != {Digit, `.`, NameStart}]

IntegerPart ::
  - NegativeSign? 0
  - NegativeSign? NonZeroDigit Digit*

NegativeSign :: -

NonZeroDigit :: Digit but not `0`

An {IntValue} is specified without a decimal point or exponent but may be
negative (ex. {-123}). It must not have any leading {0}.

An {IntValue} must not be followed by a {Digit}. In other words, an {IntValue}
token is always the longest possible valid sequence. The source characters
{12} cannot be interpreted as two tokens since {1} is followed by the {Digit}
{2}. This also means the source {00} is invalid since it can neither be
interpreted as a single token nor two {0} tokens.

An {IntValue} must not be followed by a {`.`} or {NameStart}. If either {`.`} or
{ExponentIndicator} follows then the token must only be interpreted as a
possible {FloatValue}. No other {NameStart} character can follow. For example
the sequences `0x123` and `123L` have no valid lexical representations.


### Float Value

FloatValue ::
  - IntegerPart FractionalPart ExponentPart [lookahead != {Digit, `.`, NameStart}]
  - IntegerPart FractionalPart [lookahead != {Digit, `.`, NameStart}]
  - IntegerPart ExponentPart [lookahead != {Digit, `.`, NameStart}]

FractionalPart :: . Digit+

ExponentPart :: ExponentIndicator Sign? Digit+

ExponentIndicator :: one of `e` `E`

Sign :: one of + -

A {FloatValue} includes either a decimal point (ex. {1.0}) or an exponent
(ex. {1e50}) or both (ex. {6.0221413e23}) and may be negative. Like {IntValue},
it also must not have any leading {0}.

A {FloatValue} must not be followed by a {Digit}. In other words, a {FloatValue}
token is always the longest possible valid sequence. The source characters
{1.23} cannot be interpreted as two tokens since {1.2} is followed by the
{Digit} {3}.

A {FloatValue} must not be followed by a {.}. For example, the sequence {1.23.4}
cannot be interpreted as two tokens ({1.2}, {3.4}).

A {FloatValue} must not be followed by a {NameStart}. For example the sequence
`0x1.2p3` has no valid lexical representation.

Note: The numeric literals {IntValue} and {FloatValue} both restrict being
immediately followed by a letter (or other {NameStart}) to reduce confusion
or unexpected behavior since GraphQL only supports decimal numbers.


### Boolean Value

BooleanValue : one of `true` `false`

The two keywords `true` and `false` represent the two boolean values.


### String Value

StringValue ::
  - `""` [lookahead != `"`]
  - `"` StringCharacter+ `"`
  - `"""` BlockStringCharacter* `"""`

StringCharacter ::
  - SourceCharacter but not `"` or `\` or LineTerminator
  - `\u` EscapedUnicode
  - `\` EscapedCharacter

EscapedUnicode ::
  - `{` HexDigit+ `}`
  - HexDigit HexDigit HexDigit HexDigit

HexDigit :: one of
  - `0` `1` `2` `3` `4` `5` `6` `7` `8` `9`
  - `A` `B` `C` `D` `E` `F`
  - `a` `b` `c` `d` `e` `f`

EscapedCharacter :: one of `"` `\` `/` `b` `f` `n` `r` `t`

BlockStringCharacter ::
  - SourceCharacter but not `"""` or `\"""`
  - `\"""`

{StringValue} is a sequence of characters wrapped in quotation marks (U+0022).
(ex. {`"Hello World"`}). White space and other characters ignored in other parts
of a GraphQL document are significant within a string value.

A {StringValue} is evaluated to a Unicode text value, a sequence of Unicode
scalar values, by interpreting all escape sequences using the static semantics
defined below.

The empty string {`""`} must not be followed by another {`"`} otherwise it would
be interpreted as the beginning of a block string. As an example, the source
{`""""""`} can only be interpreted as a single empty block string and not three
empty strings.

**Escape Sequences**

In a single-quoted {StringValue}, any Unicode scalar value may be expressed
using an escape sequence. GraphQL strings allow both C-style escape sequences
(for example `\n`) and two forms of Unicode escape sequences: one with a
fixed-width of 4 hexadecimal digits (for example `\u000A`) and one with a
variable-width most useful for representing a *supplementary character* such as
an Emoji (for example `\u{1F4A9}`).

The hexadecimal number encoded by a Unicode escape sequence must describe a
Unicode scalar value, otherwise parsing should stop with an early error. For
example both sources `"\uDEAD"` and `"\u{110000}"` should not be considered
valid {StringValue}.

Escape sequences are only meaningful within a single-quoted string. Within a
block string, they are simply that sequence of characters (for example
`"""\n"""` represents the Unicode text [U+005C, U+006E]). Within a comment an
escape sequence is not a significant sequence of characters. They may not appear
elsewhere in a GraphQL document.

Since {StringCharacter} must not contain some characters, escape sequences must
be used to represent these characters. All other escape sequences are optional
and unescaped non-ASCII Unicode characters are allowed within strings. If using
GraphQL within a system which only supports ASCII, then escape sequences may be
used to represent all Unicode characters outside of the ASCII range.

For legacy reasons, a *supplementary character* may be escaped by two
fixed-width unicode escape sequences forming a *surrogate pair*. For example
the input `"\uD83D\uDCA9"` is a valid {StringValue} which represents the same
Unicode text as `"\u{1F4A9}"`. While this legacy form is allowed, it should be
avoided as a variable-width unicode escape sequence is a clearer way to encode
such code points.

When producing a {StringValue}, implementations should use escape sequences to
represent non-printable control characters (U+0000 to U+001F and U+007F to
U+009F). Other escape sequences are not necessary, however an implementation may
use escape sequences to represent any other range of code points. If an
implementation chooses to escape a *supplementary character*, it should not use
a fixed-width surrogate pair unicode escape sequence.

**Block Strings**

Block strings are sequences of characters wrapped in triple-quotes (`"""`).
White space, line terminators, quote, and backslash characters may all be
used unescaped to enable verbatim text. Characters must all be valid
{SourceCharacter}.

Since block strings represent freeform text often used in indented
positions, the string value semantics of a block string excludes uniform
indentation and blank initial and trailing lines via {BlockStringValue()}.

For example, the following operation containing a block string:

```raw graphql example
mutation {
  sendEmail(message: """
    Hello,
      World!

    Yours,
      GraphQL.
  """)
}
```

Is identical to the standard quoted string:

```graphql example
mutation {
  sendEmail(message: "Hello,\n  World!\n\nYours,\n  GraphQL.")
}
```

Since block string values strip leading and trailing empty lines, there is no
single canonical printed block string for a given value. Because block strings
typically represent freeform text, it is considered easier to read if they begin
and end with an empty line.

```graphql example
"""
This starts with and ends with an empty line,
which makes it easier to read.
"""
```

```graphql counter-example
"""This does not start with or end with any empty lines,
which makes it a little harder to read."""
```

Note: If non-printable ASCII characters are needed in a string value, a standard
quoted string with appropriate escape sequences must be used instead of a
block string.

**Static Semantics**

A {StringValue} describes a Unicode text value, a sequence of *Unicode scalar
value*s. These semantics describe how to apply the {StringValue} grammar to a
source text to evaluate a Unicode text. Errors encountered during this
evaluation are considered a failure to apply the {StringValue} grammar to a
source and result in a parsing error.

StringValue :: `""`

  * Return an empty sequence.

StringValue :: `"` StringCharacter+ `"`

  * Return the concatenated sequence of *Unicode scalar value* by evaluating all
    {StringCharacter}.

StringCharacter :: SourceCharacter but not `"` or `\` or LineTerminator

  * Return the *Unicode scalar value* {SourceCharacter}.

StringCharacter :: `\u` EscapedUnicode

  * Let {value} be the hexadecimal value represented by the sequence of
    {HexDigit} within {EscapedUnicode}.
  * Assert {value} is a within the *Unicode scalar value* range (>= 0x0000 and
    <= 0xD7FF or >= 0xE000 and <= 0x10FFFF).
  * Return the code point {value}.

StringCharacter :: `\u` HexDigit HexDigit HexDigit HexDigit `\u` HexDigit HexDigit HexDigit HexDigit

  * Let {leadingValue} be the hexadecimal value represented by the first
    sequence of {HexDigit}.
  * Let {trailingValue} be the hexadecimal value represented by the second
    sequence of {HexDigit}.
  * If {leadingValue} is >= 0xD800 and <= 0xDBFF (a *Leading Surrogate*):
    * Assert {trailingValue} is >= 0xDC00 and <= 0xDFFF (a *Trailing Surrogate*).
    * Return ({leadingValue} - 0xD800) × 0x400 + ({trailingValue} - 0xDC00) + 0x10000.
  * Otherwise:
    * Assert {leadingValue} is within the *Unicode scalar value* range.
    * Assert {trailingValue} is within the *Unicode scalar value* range.
    * Return the sequence of the code point {leadingValue} followed by the code
      point {trailingValue}.

Note: If both escape sequences encode a *Unicode scalar value*, then this
semantic is identical to applying the prior semantic on each fixed-width escape
sequence. A variable-width escape sequence must only encode a
*Unicode scalar value*.

StringCharacter :: `\` EscapedCharacter

  * Return the code point represented by {EscapedCharacter} according to the
    table below.

| Escaped Character | Code Point | Character Name               |
| ----------------- | ---------- | ---------------------------- |
| {`"`}             | U+0022     | double quote                 |
| {`\`}             | U+005C     | reverse solidus (back slash) |
| {`/`}             | U+002F     | solidus (forward slash)      |
| {`b`}             | U+0008     | backspace                    |
| {`f`}             | U+000C     | form feed                    |
| {`n`}             | U+000A     | line feed (new line)         |
| {`r`}             | U+000D     | carriage return              |
| {`t`}             | U+0009     | horizontal tab               |

StringValue :: `"""` BlockStringCharacter* `"""`

  * Let {rawValue} be the concatenated sequence of *Unicode scalar value* by
    evaluating all {BlockStringCharacter} (which may be an empty sequence).
  * Return the result of {BlockStringValue(rawValue)}.

BlockStringCharacter :: SourceCharacter but not `"""` or `\"""`

  * Return the *Unicode scalar value* {SourceCharacter}.

BlockStringCharacter :: `\"""`

  * Return the character sequence `"""`.

BlockStringValue(rawValue):

  * Let {lines} be the result of splitting {rawValue} by {LineTerminator}.
  * Let {commonIndent} be {null}.
  * For each {line} in {lines}:
    * If {line} is the first item in {lines}, continue to the next line.
    * Let {length} be the number of characters in {line}.
    * Let {indent} be the number of leading consecutive {WhiteSpace} characters
      in {line}.
    * If {indent} is less than {length}:
      * If {commonIndent} is {null} or {indent} is less than {commonIndent}:
        * Let {commonIndent} be {indent}.
  * If {commonIndent} is not {null}:
    * For each {line} in {lines}:
      * If {line} is the first item in {lines}, continue to the next line.
      * Remove {commonIndent} characters from the beginning of {line}.
  * While the first item {line} in {lines} contains only {WhiteSpace}:
    * Remove the first item from {lines}.
  * While the last item {line} in {lines} contains only {WhiteSpace}:
    * Remove the last item from {lines}.
  * Let {formatted} be the empty character sequence.
  * For each {line} in {lines}:
    * If {line} is the first item in {lines}:
      * Append {formatted} with {line}.
    * Otherwise:
      * Append {formatted} with a line feed character (U+000A).
      * Append {formatted} with {line}.
  * Return {formatted}.


### Null Value

NullValue : `null`

Null values are represented as the keyword {null}.

GraphQL has two semantically different ways to represent the lack of a value:

  * Explicitly providing the literal value: {null}.
  * Implicitly not providing a value at all.

For example, these two field calls are similar, but are not identical:

```graphql example
{
  field(arg: null)
  field
}
```

The first has explicitly provided {null} to the argument "arg", while the second
has implicitly not provided a value to the argument "arg". These two forms may
be interpreted differently. For example, a mutation representing deleting a
field vs not altering a field, respectively. Neither form may be used for an
input expecting a Non-Null type.

Note: The same two methods of representing the lack of a value are possible via
variables by either providing the variable value as {null} or not providing
a variable value at all.


### Enum Value

EnumValue : Name but not `true`, `false` or `null`

Enum values are represented as unquoted names (ex. `MOBILE_WEB`). It is
recommended that Enum values be "all caps". Enum values are only used in
contexts where the precise enumeration type is known. Therefore it's not
necessary to supply an enumeration type name in the literal.


### List Value

ListValue[Const] :
  - [ ]
  - [ Value[?Const]+ ]

Lists are ordered sequences of values wrapped in square-brackets `[ ]`. The
values of a List literal may be any value literal or variable (ex. `[1, 2, 3]`).

Commas are optional throughout GraphQL so trailing commas are allowed and repeated
commas do not represent missing values.

**Semantics**

ListValue : [ ]

  * Return a new empty list value.

ListValue : [ Value+ ]

  * Let {inputList} be a new empty list value.
  * For each {Value+}
    * Let {value} be the result of evaluating {Value}.
    * Append {value} to {inputList}.
  * Return {inputList}


### Input Object Values

ObjectValue[Const] :
  - { }
  - { ObjectField[?Const]+ }

ObjectField[Const] : Name : Value[?Const]

Input object literal values are unordered lists of keyed input values wrapped in
curly-braces `{ }`. The values of an object literal may be any input value
literal or variable (ex. `{ name: "Hello world", score: 1.0 }`). We refer to
literal representation of input objects as "object literals."

**Input object fields are unordered**

Input object fields may be provided in any syntactic order and maintain
identical semantic meaning.

These two operations are semantically identical:

```graphql example
{
  nearestThing(location: { lon: 12.43, lat: -53.211 })
}
```

```graphql example
{
  nearestThing(location: { lat: -53.211, lon: 12.43 })
}
```

**Semantics**

ObjectValue : { }

  * Return a new input object value with no fields.

ObjectValue : { ObjectField+ }

  * Let {inputObject} be a new input object value with no fields.
  * For each {field} in {ObjectField+}
    * Let {name} be {Name} in {field}.
    * Let {value} be the result of evaluating {Value} in {field}.
    * Add a field to {inputObject} of name {name} containing value {value}.
  * Return {inputObject}


## Variables

Variable : $ Name

VariableDefinitions : ( VariableDefinition+ )

VariableDefinition : Variable : Type DefaultValue? Directives[Const]?

DefaultValue : = Value[Const]

A GraphQL operation can be parameterized with variables, maximizing reuse,
and avoiding costly string building in clients at runtime.

If not defined as constant (for example, in {DefaultValue}), a {Variable} can be
supplied for an input value.

Variables must be defined at the top of an operation and are in scope
throughout the execution of that operation. Values for those variables are
provided to a GraphQL service as part of a request so they may be substituted
in during execution.

In this example, we want to fetch a profile picture size based on the size
of a particular device:

```graphql example
query getZuckProfile($devicePicSize: Int) {
  user(id: 4) {
    id
    name
    profilePic(size: $devicePicSize)
  }
}
```

If providing JSON for the variables' values, we could request a `profilePic` of
size `60`:

```json example
{
  "devicePicSize": 60
}
```

**Variable use within Fragments**

Variables can be used within fragments. Variables have global scope with a given operation, so a variable used within a fragment must be declared in any
top-level operation that transitively consumes that fragment. If a variable is
referenced in a fragment and is included by an operation that does not define
that variable, that operation is invalid (see [All Variable Uses Defined](#sec-All-Variable-Uses-Defined)).


## Type References

Type :
  - NamedType
  - ListType
  - NonNullType

NamedType : Name

ListType : [ Type ]

NonNullType :
  - NamedType !
  - ListType !

GraphQL describes the types of data expected by arguments and variables.
Input types may be lists of another input type, or a non-null variant of any
other input type.

**Semantics**

Type : Name

  * Let {name} be the string value of {Name}
  * Let {type} be the type defined in the Schema named {name}
  * {type} must not be {null}
  * Return {type}

Type : [ Type ]

  * Let {itemType} be the result of evaluating {Type}
  * Let {type} be a List type where {itemType} is the contained type.
  * Return {type}

Type : Type !

  * Let {nullableType} be the result of evaluating {Type}
  * Let {type} be a Non-Null type where {nullableType} is the contained type.
  * Return {type}


## Directives

Directives[Const] : Directive[?Const]+

Directive[Const] : @ Name Arguments[?Const]?

Directives provide a way to describe alternate runtime execution and type
validation behavior in a GraphQL document.

In some cases, you need to provide options to alter GraphQL's execution
behavior in ways field arguments will not suffice, such as conditionally
including or skipping a field. Directives provide this by describing additional information to the executor.

Directives have a name along with a list of arguments which may accept values
of any input type.

Directives can be used to describe additional information for types, fields,
fragments and operations.

As future versions of GraphQL adopt new configurable execution capabilities,
they may be exposed via directives. GraphQL services and tools may also provide
any additional *custom directive* beyond those described here.

**Directive order is significant**

Directives may be provided in a specific syntactic order which may have semantic interpretation.

These two type definitions may have different semantic meaning:

```graphql example
type Person
  @addExternalFields(source: "profiles")
  @excludeField(name: "photo") {
  name: String
}
```

```graphql example
type Person
  @excludeField(name: "photo")
  @addExternalFields(source: "profiles") {
  name: String
}
```
