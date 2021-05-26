# A. Appendix: Notation Conventions

This specification document contains a number of notation conventions used to
describe technical concepts such as language grammar and semantics as well as
runtime algorithms.

This appendix seeks to explain these notations in greater detail to avoid
ambiguity.

## Context-Free Grammar

A context-free grammar consists of a number of productions. Each production has
an abstract symbol called a "non-terminal" as its left-hand side, and zero or
more possible sequences of non-terminal symbols and or terminal characters as
its right-hand side.

Starting from a single goal non-terminal symbol, a context-free grammar
describes a language: the set of possible sequences of characters that can be
described by repeatedly replacing any non-terminal in the goal sequence with one
of the sequences it is defined by, until all non-terminal symbols have been
replaced by terminal characters.

Terminals are represented in this document in a monospace font in two forms: a
specific Unicode character or sequence of Unicode characters (ie. {`=`} or
{`terminal`}), and prose typically describing a specific Unicode code-point
{"Space (U+0020)"}. Sequences of Unicode characters only appear in syntactic
grammars and represent a {Name} token of that specific sequence.

Non-terminal production rules are represented in this document using the
following notation for a non-terminal with a single definition:

NonTerminalWithSingleDefinition : NonTerminal `terminal`

While using the following notation for a production with a list of definitions:

NonTerminalWithManyDefinitions :

- OtherNonTerminal `terminal`
- `terminal`

A definition may refer to itself, which describes repetitive sequences, for
example:

ListOfLetterA :

- ListOfLetterA `a`
- `a`

## Lexical and Syntactical Grammar

The GraphQL language is defined in a syntactic grammar where terminal symbols
are tokens. Tokens are defined in a lexical grammar which matches patterns of
source characters. The result of parsing a source text sequence of Unicode
characters first produces a sequence of lexical tokens according to the lexical
grammar which then produces abstract syntax tree (AST) according to the
syntactical grammar.

A lexical grammar production describes non-terminal "tokens" by patterns of
terminal Unicode characters. No "whitespace" or other ignored characters may
appear between any terminal Unicode characters in the lexical grammar
production. A lexical grammar production is distinguished by a two colon `::`
definition.

Word :: Letter+

A Syntactical grammar production describes non-terminal "rules" by patterns of
terminal Tokens. {WhiteSpace} and other {Ignored} sequences may appear before or
after any terminal {Token}. A syntactical grammar production is distinguished by
a one colon `:` definition.

Sentence : Word+ `.`

## Grammar Notation

This specification uses some additional notation to describe common patterns,
such as optional or repeated patterns, or parameterized alterations of the
definition of a non-terminal. This section explains these short-hand notations
and their expanded definitions in the context-free grammar.

**Constraints**

A grammar production may specify that certain expansions are not permitted by
using the phrase "but not" and then indicating the expansions to be excluded.

For example, the following production means that the non-terminal {SafeWord} may
be replaced by any sequence of characters that could replace {Word} provided
that the same sequence of characters could not replace {SevenCarlinWords}.

SafeWord : Word but not SevenCarlinWords

A grammar may also list a number of restrictions after "but not" separated by
"or".

For example:

NonBooleanName : Name but not `true` or `false`

**Lookahead Restrictions**

A grammar production may specify that certain characters or tokens are not
permitted to follow it by using the pattern {[lookahead != NotAllowed]}.
Lookahead restrictions are often used to remove ambiguity from the grammar.

The following example makes it clear that {Letter+} must be greedy, since {Word}
cannot be followed by yet another {Letter}.

Word :: Letter+ [lookahead != Letter]

**Optionality and Lists**

A subscript suffix "{Symbol?}" is shorthand for two possible sequences, one
including that symbol and one excluding it.

As an example:

Sentence : Noun Verb Adverb?

is shorthand for

Sentence :

- Noun Verb Adverb
- Noun Verb

A subscript suffix "{Symbol+}" is shorthand for a list of one or more of that
symbol, represented as an additional recursive production.

As an example:

Book : Cover Page+ Cover

is shorthand for

Book : Cover Page_list Cover

Page_list :

- Page_list Page
- Page

**Parameterized Grammar Productions**

A symbol definition subscript suffix parameter in braces "{Symbol[Param]}" is
shorthand for two symbol definitions, one appended with that parameter name, the
other without. The same subscript suffix on a symbol is shorthand for that
variant of the definition. If the parameter starts with "?", that form of the
symbol is used if in a symbol definition with the same parameter. Some possible
sequences can be included or excluded conditionally when respectively prefixed
with "\[+Param]" and "\[~Param]".

As an example:

Example[Param] :

- A
- B[Param]
- C[?Param]
- [+Param] D
- [~Param] E

is shorthand for

Example :

- A
- B_param
- C
- E

Example_param :

- A
- B_param
- C_param
- D

## Grammar Semantics

This specification describes the semantic value of many grammar productions in
the form of a list of algorithmic steps.

For example, this describes how a parser should interpret a string literal:

StringValue :: `""`

- Return an empty Unicode character sequence.

StringValue :: `"` StringCharacter+ `"`

- Return the Unicode character sequence of all {StringCharacter} Unicode
  character values.

## Algorithms

This specification describes some algorithms used by the static and runtime
semantics, they're defined in the form of a function-like syntax with the
algorithm's name and the arguments it accepts along with a list of algorithmic
steps to take in the order listed. Each step may establish references to other
values, check various conditions, call other algorithms, and eventually return a
value representing the outcome of the algorithm for the provided arguments.

For example, the following example describes an algorithm named {Fibonacci}
which accepts a single argument {number}. The algorithm's steps produce the next
number in the Fibonacci sequence:

Fibonacci(number):

- If {number} is {0}:
  - Return {1}.
- If {number} is {1}:
  - Return {2}.
- Let {previousNumber} be {number} - {1}.
- Let {previousPreviousNumber} be {number} - {2}.
- Return {Fibonacci(previousNumber)} + {Fibonacci(previousPreviousNumber)}.

Note: Algorithms described in this document are written to be easy to
understand. Implementers are encouraged to include equivalent but optimized
implementations.
