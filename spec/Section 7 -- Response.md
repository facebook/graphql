# Response

When a GraphQL service receives a request, it must return a well-formed
response. The service's response describes the result of executing the requested
operation if successful, and describes any errors encountered during the
request.

A response may contain both a partial response as well as encountered errors in
the case that a field error occurred on a field which was replaced with {null}.

A response to a GraphQL operation must be a map or an event stream of maps. The
value of this map is described in the "Response Format" section.

## Response Format

If the operation encountered any errors, the response map must contain an
entry with key `errors`. The value of this entry is described in the "Errors"
section. If the operation completed without encountering any errors, this entry
must not be present.

If the operation included execution, the response map must contain an entry
with key `data`. The value of this entry is described in the "Data" section. If
the operation failed before execution, due to a syntax error, missing
information, or validation error, this entry must not be present.

When the response of the GraphQL operation is an event stream, the first value
will be the initial response. All subsequent values may contain `label` and 
`path` entries. These two entries are used by clients to identify the the 
`@defer` or `@stream` directive from the GraphQL operation that triggered this
value to be returned by the event stream. The combination of these two entries
must be unique across all values returned by the event stream. 

If the response of the GraphQL operation is an event stream, each response map
must contain an entry with key `hasNext`. The value of this entry is `true` for
all but the last response in the stream. The value of this entry is `false` for 
the last response of the stream. This entry is not required for GraphQL 
operations that return a single response map. 

The GraphQL server may determine there are no more values in the event stream 
after a previous value with `hasNext` equal to `true` has been emitted. In this case 
the last value in the event stream should be a map without `data`, `label`, 
and `path` entries, and a `hasNext` entry with a value of `false`.

The response map may also contain an entry with key `extensions`. This entry,
if set, must have a map as its value. This entry is reserved for implementors
to extend the protocol however they see fit, and hence there are no additional
restrictions on its contents.

To ensure future changes to the protocol do not break existing services and
clients, the top level response map must not contain any entries other than the
three described above.

Note: When `errors` is present in the response, it may be helpful for it to
appear first when serialized to make it more clear when errors are present
in a response during debugging.

### Data

The `data` entry in the response will be the result of the execution of the
requested operation. If the operation was a query, this output will be an
object of the schema's query root type; if the operation was a mutation, this
output will be an object of the schema's mutation root type.

If the result of the operation is an event stream, the `data` entry in 
subsequent values will be an object of the type of a particular field in the
GraphQL result. The adjacent `path` field will contain the path segments of 
the field this data is associated with.

If an error was encountered before execution begins, the `data` entry should
not be present in the result.

If an error was encountered during the execution that prevented a valid
response, the `data` entry in the response should be `null`.


### Errors

The `errors` entry in the response is a non-empty list of errors, where each
error is a map.

If no errors were encountered during the requested operation, the `errors`
entry should not be present in the result.

If the `data` entry in the response is not present, the `errors`
entry in the response must not be empty. It must contain at least one error.
The errors it contains should indicate why no data was able to be returned.

If the `data` entry in the response is present (including if it is the value
{null}), the `errors` entry in the response may contain any errors that
occurred during execution. If errors occurred during execution, it should
contain those errors.

**Error result format**

Every error must contain an entry with the key `message` with a string
description of the error intended for the developer as a guide to understand
and correct the error.

If an error can be associated to a particular point in the requested GraphQL
document, it should contain an entry with the key `locations` with a list of
locations, where each location is a map with the keys `line` and `column`, both
positive numbers starting from `1` which describe the beginning of an
associated syntax element.

If an error can be associated to a particular field in the GraphQL result, it
must contain an entry with the key `path` that details the path of the
response field which experienced the error. This allows clients to identify
whether a `null` result is intentional or caused by a runtime error. The value 
of this field is described in the "Path" section.

For example, if fetching one of the friends' names fails in the following
query:

```graphql example
{
  hero(episode: $episode) {
    name
    heroFriends: friends {
      id
      name
    }
  }
}
```

The response might look like:

```json example
{
  "errors": [
    {
      "message": "Name for character with ID 1002 could not be fetched.",
      "locations": [{ "line": 6, "column": 7 }],
      "path": ["hero", "heroFriends", 1, "name"]
    }
  ],
  "data": {
    "hero": {
      "name": "R2-D2",
      "heroFriends": [
        {
          "id": "1000",
          "name": "Luke Skywalker"
        },
        {
          "id": "1002",
          "name": null
        },
        {
          "id": "1003",
          "name": "Leia Organa"
        }
      ]
    }
  }
}
```

If the field which experienced an error was declared as `Non-Null`, the `null`
result will bubble up to the next nullable field. In that case, the `path`
for the error should include the full path to the result field where the error
occurred, even if that field is not present in the response.

For example, if the `name` field from above had declared a `Non-Null` return
type in the schema, the result would look different but the error reported would
be the same:

```json example
{
  "errors": [
    {
      "message": "Name for character with ID 1002 could not be fetched.",
      "locations": [{ "line": 6, "column": 7 }],
      "path": ["hero", "heroFriends", 1, "name"]
    }
  ],
  "data": {
    "hero": {
      "name": "R2-D2",
      "heroFriends": [
        {
          "id": "1000",
          "name": "Luke Skywalker"
        },
        null,
        {
          "id": "1003",
          "name": "Leia Organa"
        }
      ]
    }
  }
}
```

GraphQL services may provide an additional entry to errors with key `extensions`.
This entry, if set, must have a map as its value. This entry is reserved for
implementors to add additional information to errors however they see fit, and
there are no additional restrictions on its contents.

```json example
{
  "errors": [
    {
      "message": "Name for character with ID 1002 could not be fetched.",
      "locations": [{ "line": 6, "column": 7 }],
      "path": ["hero", "heroFriends", 1, "name"],
      "extensions": {
        "code": "CAN_NOT_FETCH_BY_ID",
        "timestamp": "Fri Feb 9 14:33:09 UTC 2018"
      }
    }
  ]
}
```

GraphQL services should not provide any additional entries to the error format
since they could conflict with additional entries that may be added in future
versions of this specification.

Note: Previous versions of this spec did not describe the `extensions` entry
for error formatting. While non-specified entries are not violations, they are
still discouraged.

```json counter-example
{
  "errors": [
    {
      "message": "Name for character with ID 1002 could not be fetched.",
      "locations": [{ "line": 6, "column": 7 }],
      "path": ["hero", "heroFriends", 1, "name"],
      "code": "CAN_NOT_FETCH_BY_ID",
      "timestamp": "Fri Feb 9 14:33:09 UTC 2018"
    }
  ]
}
```


## Path

A `path` field allows for the association to a particular field in a GraphQL 
result. This field should be a list of path segments starting at the root of the
response and ending with the field to be associated with. Path segments
that represent fields should be strings, and path segments that
represent list indices should be 0-indexed integers. If the path is associated to
an aliased field, the path should use the aliased name, since it represents a path in the response, not in the query.

When the `path` field is present on a GraphQL response, it indicates that the 
`data` field is not the root query or mutation result, but is rather associated to
a particular field in the root result.

When the `path` field is present on an "Error result", it indicates the response field which experienced the error.

## Label

If the response of the GraphQL operation is an event stream, subsequent values
may contain a string field `label`. This `label` is the same label passed to 
the `@defer` or `@stream` directive that triggered this value. This allows 
clients to identify which `@defer` or `@stream` directive is associated with
this value. `label` will not be present if the corresponding `@defer` or 
`@stream` directive is not passed a `label` argument.

## Serialization Format

GraphQL does not require a specific serialization format. However, clients
should use a serialization format that supports the major primitives in the
GraphQL response. In particular, the serialization format must at least support
representations of the following four primitives:

 * Map
 * List
 * String
 * Null

A serialization format should also support the following primitives, each
representing one of the common GraphQL scalar types, however a string or simpler
primitive may be used as a substitute if any are not directly supported:

 * Boolean
 * Int
 * Float
 * Enum Value

This is not meant to be an exhaustive list of what a serialization format may
encode. For example custom scalars representing a Date, Time, URI, or number
with a different precision may be represented in whichever relevant format a
given serialization format may support.


### JSON Serialization

JSON is the most common serialization format for GraphQL. Though as mentioned
above, GraphQL does not require a specific serialization format.

When using JSON as a serialization of GraphQL responses, the following JSON
values should be used to encode the related GraphQL values:

| GraphQL Value | JSON Value        |
| ------------- | ----------------- |
| Map           | Object            |
| List          | Array             |
| Null          | {null}            |
| String        | String            |
| Boolean       | {true} or {false} |
| Int           | Number            |
| Float         | Number            |
| Enum Value    | String            |

Note: For consistency and ease of notation, examples of responses are given in
JSON format throughout this document.


### Serialized Map Ordering

Since the result of evaluating a selection set is ordered, the serialized Map of
results should preserve this order by writing the map entries in the same order
as those fields were requested as defined by query execution. Producing a
serialized response where fields are represented in the same order in which
they appear in the request improves human readability during debugging and
enables more efficient parsing of responses if the order of properties can
be anticipated.

Serialization formats which represent an ordered map should preserve the
order of requested fields as defined by {CollectFields()} in the Execution
section. Serialization formats which only represent unordered maps but where
order is still implicit in the serialization's textual order (such as JSON)
should preserve the order of requested fields textually.

For example, if the request was `{ name, age }`, a GraphQL service responding in
JSON should respond with `{ "name": "Mark", "age": 30 }` and should not respond
with `{ "age": 30, "name": "Mark" }`.

While JSON Objects are specified as an
[unordered collection of key-value pairs](https://tools.ietf.org/html/rfc7159#section-4)
the pairs are represented in an ordered manner. In other words, while the JSON
strings `{ "name": "Mark", "age": 30 }` and `{ "age": 30, "name": "Mark" }`
encode the same value, they also have observably different property orderings.

Note: This does not violate the JSON spec, as clients may still interpret
objects in the response as unordered Maps and arrive at a valid value.
