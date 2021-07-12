## RFC: GraphQL Defer and Stream Directives

_Working Draft - July 2020_

# Introduction

One of the disadvantages of GraphQL’s request/response model is that
applications which retrieve large datasets may suffer from latency. However not
all requested data may be of equal importance, and in some use cases it may be
possible for applications to act on a subset of the requested data.

Today applications which seek to ensure that data of high importance can be
retrieved quickly have a few options:

- Splitting queries
- Prefetching

However each of these solutions imposes some undesirable trade-offs on
applications.

## Splitting queries

Given a query where some fields are expensive and non-essential, non-essential
fields can be fetched in a separate query issued after an initial query. In the
context of lists, this may mean fetching only the first few items in a list and
issuing a follow-up pagination request for additional items. By separating the
requests based on data priority, we have achieved a faster delivery time to
essential data. However, query splitting imposes several **trade-offs** on
applications:

**Increased latency for lower priority fields,** as now these fields have to
wait for the original query to complete and have added network round trips
**Client resource contention.** Issuing multiple requests can increase
contention on scarce resources like battery and antenna. **Increased cost.**
Processing additional requests can increase server costs by putting pressure on
both the middle tier and the data layer. For example a follow-up query may need
to load a subset of the same data loaded by the initial query, putting
additional pressure on data stores.

## Prefetching

This technique involves optimistically fetching data based on a prediction that
a user will execute an action. Prefetching can be one of the most effective ways
of reducing latency. However, a significant tradeoff with prefetching that a lot
of applications cannot afford is **increased server cost due to incorrect
predictions.** With an unsophisticated prefetch algorithm, applications can
easily overfetch by a factor of 10 fold.

# Proposal: Incrementally deliver data with `@defer` and `@stream`

This proposal would introduce `@stream` and `@defer` directives which clients
could use to communicate the relative priority of requested data to GraphQL
implementations. Furthermore this proposal would enable GraphQL APIs to split
requested data across multiple response payloads in order of priority. The goal
of this proposal is to enable applications to reduce latency without increasing
server cost or resource contention.

While both incremental delivery and GraphQL subscriptions send multiple payloads
over time, **incremental delivery is _not_ intended to enable applications to
respond to real-time changes.** Consequently streams opened for incremental
delivery are expected to be short-lived. **Implementations are not required to
reflect interleaving mutations which occur during incremental delivery.**
Assuming there are no interleaving mutations, combining together the various
payloads in an incrementally delivered response should produce the same output
as if that response was not delivered incrementally.

Facebook has been using Incremental Delivery at scale since 2017, including on
major surfaces such as news feed. This proposal captures the key concepts that
we have found to be useful.

GraphQL servers will not be required to implement `@defer` and/or `@stream`. If
they are implemented, they will be required to follow the proposed
specification. Servers that do not implement `@defer` and/or `@stream` should
not expose these directives in their schema. Queries containing these directives
that are sent to an unsupported server should fail validation.

## `@defer`

The `@defer` directive may be specified on a fragment spread to imply
de-prioritization, that causes the fragment to be omitted in the initial
response, and delivered as a subsequent response afterward. A query with
`@defer` directive will cause the request to potentially return multiple
responses, where non-deferred data is delivered in the initial response and data
deferred delivered in a subsequent response. `@include` and `@skip` take
precedence over `@defer`.

### `@defer` arguments

- `if: Boolean`
  - When `true` fragment may be deferred, if omitted defaults to `true`.
- `label: String`
  - A unique label across all `@defer` and `@stream` directives in an operation.
  - This `label` should be used by GraphQL clients to identify the data from
    patch responses and associate it with the correct fragment.
  - If provided, the GraphQL Server must add it to the payload.

## `@stream`

The `@stream` directive may be provided for a field of `List` type so that the
backend can leverage technology such asynchronous iterators to provide a partial
list in the initial response, and additional list items in subsequent responses.
`@include` and `@skip` take precedence over `@stream`.

### `@stream` arguments

- `if: Boolean`
  - When `true` field may be streamed, if omitted defaults to `true`.
- `label: String`
  - A unique label across all `@defer` and `@stream` directives in an operation.
  - This `label` should be used by GraphQL clients to identify the data from
    patch responses and associate it with the correct fragments.
  - If provided, the GraphQL Server must add it to the payload.
- `initialCount: Int`
  - The number of list items the server should return as part of the initial
    response.

## Payload format

When an operation contains `@defer` or `@stream` directives, the GraphQL
execution will return multiple payloads. The first payload is the same shape as
a standard GraphQL response. Any fields that were only requested on a fragment
that is deferred will not be present in this payload. Any list fields that are
streamed will only contain the initial list items.

Each subsequent payload will be an object with the following properties:

- `label`: The string that was passed to the label argument of the `@defer` or
  `@stream` directive that corresponds to this result.
- `data`: The data that is being delivered incrementally.
- `path`: a list of keys (with plural indexes) from the root of the response to
  the insertion point that informs the client how to patch a subsequent delta
  payload into the original payload.
- `hasNext`: A boolean that is present and `true` when there are more payloads
  that will be sent for this operation. The last payload in a multi-payload
  response should return `hasNext: false`. `hasNext` is not required for
  single-payload responses to preserve backwards compatibility.
- `errors`: An array that will be present and contain any field errors that are
  produced while executing the deferred or streamed selection set.
- `extensions`: For implementors to extend the protocol.

Note: The `label` field is not a unique identifier for payloads. There may be
multiple payloads with the same label for either payloads for `@stream`, or
payloads from a `@defer` fragment under a list field. The combination of `label`
and `path` will be unique among all payloads.

## Server requirements for `@defer` and `@stream`

The ability to defer/stream parts of a response can have a potentially
significant impact on application performance. Developers generally need clear,
predictable control over their application's performance. It is highly
recommended that the GraphQL server honor the `@defer` and `@stream` directives
on each execution. However, the specification will allow advanced use-cases
where the server can determine that it is more performant to not defer/stream.
Therefore, GraphQL clients should be able to process a response that ignores the
defer/stream directives.

This also applies to the `initialCount` argument on the `@stream` directive.
Clients should be able to process a streamed response that contains a different
number of initial list items than what was specified in the `initialCount`
argument.

## Example Query with `@defer` and `@stream`

```
{
  viewer {
    id
    friends(first: 2) @stream(initialCount: 1, label: "friendStream") {
	  id
    }
  }
  ...GroupAdminFragment @defer(label: "groupAdminDefer")
}

fragment GroupAdminFragment {
   managed_groups {
      id
   }
}

// Response payloads

// payload 1
{
    data: {id: 1},
    hasNext: true
}

// payload 2
{
  label: "friendStream"
  path: [“viewer”, “friends”, 1],
  data: {id: 4},
  hasNext: true
}

// payload 3
{
  label: "friendStream"
  path: [“viewer”, “friends”, 2],
  data: {id: 5},
  hasNext: true
}

// payload 4
{
  label: "groupAdminDefer",
  path: [“viewer”],
  data: {managed_groups: [{id: 1, id: 2}]}
  hasNext: false
}
```

## Benefits of incremental delivery

- Make GraphQL a great choice for applications which demand responsiveness.
- Enable interoperability between different GraphQL clients and servers without
  restricting implementation.
- Enable a strong tooling ecosystem (including GraphiQL).
- Provide concrete guidance to implementers.
- Provide guidance to developers evaluating whether to adopt incremental
  delivery.

## Use case guidance:

The goal of incremental delivery is to prioritize the delivery of essential
data. Even though incremental delivery delivers data over time, the response
describes the data at a particular point in time. Therefore, it is not necessary
to reflect real time changes to the data model in incremental delivery.
Implementers of `@defer` and `@stream` are not obligated to address interleaving
mutations during the execution of `@defer` and `@stream`.

GraphQL Subscription is an event-oriented approach to capture real time data
changes. It intends to describe interesting events that happen over a period of
time and delivers updated values that “invalidate” previous values.

## Implementation details of `@stream` and `@defer`

For GraphQL communications built on top of HTTP, a natural and compatible
technology to leverage is HTTP chunked encoding to implement a stream of
responses for incremental delivery.

## Caveats

### Type Generation

Supporting `@defer` can add complexity to type-generating clients. Separate
types will need to be generated for the different deferred fragments. These
clients will need to use the `label` field to determine which fragments have
been fulfilled to ensure the application is using the correct types.

### Object Consistency

The GraphQL spec does not currently support object identification or
consistency. It is currently possible for the same object to be returned in
multiple places in a query. If that object changes while the resolvers are
running, the query could return inconsistent results. `@defer`/`@stream` does
not increase the likelihood of this, as the server still attempts to resolve
everything as fast as it can. The only difference is some results can be
returned to the client sooner. This proposal does not attempt to address this
issue.

### Can `@defer`/`@stream` increase risk of a denial of service attack?

This is currently a risk in GraphQL servers that do not implement any kind of
query limiting as arbitrarily complex queries can be sent. Adding `@defer` may
add some overhead as the server will now send parts of the query earlier than it
would have without `@defer`, but it does not allow for any additional resolving
that was not previously possible.

## Frequently Asked Questions

### Why is `@defer` supported on fragments instead of fields?

The first experimental implementation of `@defer` was in Apollo Server and only
supported `@defer` on fields. When applying this to production code, we quickly
found that most use-cases were to defer a group of multiple fields, and block
the corresponding UI from rendering until all fields in the group have been
resolved. This requires the client to track the loading state of each individual
field, showing the loading indicator until it receives the asynchronous payloads
for each field. Alternatively, a client could render the UI for each individual
field as soon as it's ready. However, this could lead to a bad user experience,
with the UI repainting and reflowing many times as the data is loaded.

By supporting `@defer` on fragments, the client is signaling to the server to
return the results of the fields in the fragment, when the entire fragment has
finished resolving. The client only needs to wait for this payload before
rendering the corresponding UI.

For these reasons, this proposal only supports `@defer` on fragment spreads and
inline fragments. If only a single field needs to be deferred, an inline
fragment with `@defer` can easily wrap the field. By not allowing `@defer` on
fields, we hope to discourage bad user experiences caused by many fields loading
independently, and provide an easy upgrade path from deferring a single field to
deferring many fields.

The GraphQL WG is not ruling out supporting `@defer` on fields in the future if
additional use-cases are discovered, but it is no longer being considered for
this proposal.

## Potential concerns, challenges, and drawbacks

### Client re-renders

With incremental delivery, where multiple responses are delivered in one
request, client code could re-render its UI multiple times in a short period of
time. This could degrade performance of the application, negating the
performance gains from using `@defer` or `@stream`. There are a few approaches
that could be taken to mitigate this. Each of these approaches are orthogonal to
one another, i.e. the working group could decide that more than one of these
should be included in the spec or be labeled as best practices.

These solutions require the GraphQL client to efficiently process multiple
responses at the same time. (Relay support added here:
https://github.com/facebook/relay/commit/b4c92a23ae061943ea7a2ddb5e2f7686d3af8c0e)

1. **Client relies on transport to receive multiple responses.** If the
   incremental responses are being sent over HTTP connection with chunked
   encoding, the client may receive multiple responses in a single read of HTTP
   stream and process them at the same time. This is only likely to happen when
   the responses are small and sent very close together. This would not work for
   all possible transport types, e.g. web sockets where each frame is received
   separately.

For example, the client might receive several responses at once:

```

---
Content-Type: application/json
Content-Length: 125

{
    "path": ["viewer","itemSearch","edges",5],
    "data": {
        "node": {
            "item": {
                "attribute": "Vintage 1950s Swedish Scandinavian Modern"
            }
        }
    }
}

---
Content-Type: application/json
Content-Length: 126

{
    "path": ["viewer","itemSearch","edges",6],
    "data": {
        "node": {
            "item": {
                "attribute": "Mid-20th Century Italian Hollywood Regency"
            }
        }
    }
}

---
Content-Type: application/json
Content-Length: 124

{
    "path": ["viewer","itemSearch","edges",7],
    "data": {
        "node": {
            "item": {
                "attribute": "Vintage 1950s Italian Mid-Century Modern"
            }
        }
    }
}
```

It could then process each of these before triggering a re-render.

2. **Client side debounce.** GraphQL clients can debounce the processing of
   responses before triggering a re-render. For a query that contains `@defer`
   or `@stream`, the client will wait a predetermined amount of time starting
   from when a response is received. If any additional responses are received in
   that time, it can process the results in one batch. This has the downside of
   adding latency; if no additional responses are receiving in the timeout
   period, the processing of the initial response is delayed by the length of
   the debounce timeout. There is also significant complexity in determining the
   most optimal amount of time for debouncing. Even if this "magic number" is
   determined by analzing historical performance data, it is not constant and
   must be re-evaluated as queries and server implementation changes over time.

3. **Server sends batched responses.** This approach changes the spec to allow
   GraphQL to return either the current GraphQL Response map, or a list of
   GraphQL Response maps. This gives the server the flexibility to determine
   when it is beneficial to group incremental responses together. If several
   responses are ready at the same time, the server can deliver them together.
   The server may also have knowledge of how long resolvers will take to resolve
   and could choose to debounce. It is also worth noting that a naive debouncing
   algorithm on the server could also result in degraded performance by
   introducing latency.

An example batched response:

```json
---
[
    {
        "path": ["viewer","itemSearch","edges",5],
        "data": {
            "node": {
                "item": {
                    "attribute": "Vintage 1950s Swedish Scandinavian Modern"
                }
            }
        }
    },
    {
        "path": ["viewer","itemSearch","edges",6],
        "data": {
            "node": {
                "item": {
                    "attribute": "Mid-20th Century Italian Hollywood Regency"
                }
            }
        }
    },
    {
        "path": ["viewer","itemSearch","edges",7],
        "data": {
            "node": {
                "item": {
                    "attribute": "Vintage 1950s Italian Mid-Century Modern"
                }
            }
        }
    }
]
```

1. **Server can ignore `@defer`/`@stream`.** This approach allows the GraphQL
   server to treat `@defer` and `@stream` as hints. The server can ignore these
   directives and include the deferred data in previous responses. This requires
   clients to be written with the expectation that deferred data could arrive in
   either its own incrementally delivered response or part of a previously
   delivered response. This solution does not require the client to be able to
   process multiple responses at the same time.

# Additional material

- [1]
  [Lee Byron on idea of @defer and @stream](https://www.youtube.com/watch?v=ViXL0YQnioU&feature=youtu.be&t=9m4s)
- [2]
  [[Proposal] Introducing @defer in Apollo Server](https://blog.apollographql.com/introducing-defer-in-apollo-server-f6797c4e9d6e)
- [3]
  [Active development on @defer and @stream in Relay at Facebook](https://github.com/graphql/graphql-wg/issues/329)
