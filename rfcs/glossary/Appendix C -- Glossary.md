# C. Appendix: Glossary

This appendix seeks to act as a quick reference for some of the technical terms
used throughout this specification document.

## Glossary is Non-Normative

Where a glossary definition and the usage within the specification do not align,
this likely indicates a mistake in the glossary - the glossary is non-normative
and the specification should be treated as the "source of truth."

## Parenthesized Terms

Some terms are defined with parenthesized parts (e.g. "(GraphQL) request").
These terms can be referenced without the parenthesized parts in general, but
the parenthesized parts may be included to help resolve potential ambiguity\*
(for example: the phrase "sending a request to a server" may refer to an HTTP
request, network request, or a GraphQL request).

## Definitions

### (GraphQL) operation type

**Definition**: a type of operation supported by GraphQL; currently the
following operation types are supported:

- {`query`} - for requests which purely seek to retrieve data
- {`mutation`} - for requests which seek to change data or state
- {`subscription`} - for requests that seek to be informed when certain events
  occur

Do not confuse (GraphQL) operation type with (GraphQL) root operation type;
these concepts are distinct.

Example:

> GraphQL currently supports 3 **operation types**: `query`, `mutation` and
> `subscription`.

### (GraphQL) operation

**Definition**: an action (for example retrieving data, mutating data or state,
or subscribing to events) you wish to perform, defined via an
{OperationDefinition} (and any associated {FragmentDefinition}) within a
document.

Example:

> A query operation should not mutate data or state, for that a mutation
> operation should be used.

Example:

> Let {operation} be the result of {GetOperation(document, operationName)}.

### (GraphQL) query operation

An operation of type `query`.

Example:

> If {operation} is a query operation: ...

### (GraphQL) mutation operation

An operation of type `mutation`.

Example:

> Otherwise if {operation} is a mutation operation: ...

### (GraphQL) subscription operation

An operation of type `subscription`.

Example:

> Otherwise if {operation} is a subscription operation: ...

### (GraphQL) root operation type

The Object Type associated with a given operation type within the schema.

Example:

> A schema defines the initial root operation type for each kind of operation it
> supports: {`query`}, {`mutation`}, and {`subscription`}; this determines the
> place in the type system where those operations begin.

### (GraphQL) document

**Definition**: a textual representation using GraphQL query language of
operations, fragments, type definitions, directive definitions and/or type
extensions; defined by {Document}.

Example:

> Once a GraphQL document is written, it should always mean the same thing.

### Executable (GraphQL) document

**Definition**: the textual representation (using GraphQL query language) of an
operation (or operations) you wish to perform, including fragments as
appropriate; defined by {ExecutableDocument}.

Example:

> Clients use the GraphQL query language to make requests to a GraphQL service.
> We refer to these request sources as executable GraphQL documents. A document
> may contain operations (queries, mutations, and subscriptions) as well as
> fragments, a common unit of composition allowing for data requirement reuse.

Example:

> Documents are only executable by a GraphQL service if they are
> {ExecutableDocument} and contain at least one {OperationDefinition}.

### (GraphQL) variables

**Definition**: placeholder for a value within an operation that may be supplied
at runtime; defined via {VariableDefinitions}.

Example:

> Variables must be defined at the top of an operation and are in scope
> throughout the execution of that operation.

Example:

> `$devicePicSize` is an operation variable in the following operation:
>
> ```graphql example
> query getZuckProfile($devicePicSize: Int) {
>   user(id: 4) {
>     id
>     name
>     profilePic(size: $devicePicSize)
>   }
> }
> ```

### (GraphQL) request

**Definition**: the full description of what you wish GraphQL to execute,
including the GraphQL schema, document, variables, operation name and initial
value. See {ExecuteRequest()}.

Note: The GraphQL schema and initial value are commonly implicit at the
transport level; for example when a GraphQL schema is exposed over HTTP,
accessing this HTTP endpoint _implicitly_ defines the GraphQL schema to use.

> When using GraphQL over HTTP, it's common to encode the GraphQL request as
> JSON.

### (GraphQL) request error

**Definition**: an error which occurs whilst preparing a GraphQL request for
execution (including parsing and validating the document, determining the
operation, and coercing the variables) resulting in the entire GraphQL request
being aborted before execution can begin. See [Errors](#sec-Errors).

Example:

> Request errors are raised before execution begins. This may occur due to a
> parse grammar or validation error in the requested document, an inability to
> determine which operation to execute, or invalid input values for variables.
