RFC: GraphQL Defer and Stream Directives
-------

*Working Draft - January 2020*

# Introduction

One of the disadvantages of GraphQL’s request/response model is that applications which retrieve large datasets may suffer from latency. However not all requested data may be of equal importance, and in some use cases it may be possible for applications to act on a subset of the requested data.  

Today applications which seek to ensure that data of high importance can be retrieved quickly have a few options:

* Splitting queries
* Prefetching

However each of these solutions imposes some undesirable trade-offs on applications.

## Splitting queries

Given a query where some fields are expensive and non-essential, non-essential fields can be fetched in a separate query issued after an initial query. In the context of lists, this may mean fetching only the first few items in a list and issuing a follow-up pagination request for additional items. By separating the requests based on data priority, we have achieved a faster delivery time to essential data. However, query splitting imposes several **trade-offs** on applications:

**Increased latency for lower priority fields,** as now these fields have to wait for the original query to complete and have added network round trips
**Client resource contention.** Issuing multiple requests can increase contention on scarce resources like battery and antenna. 
**Increased cost.** Processing additional requests can increase server costs by putting pressure on both the middle tier and the data layer. For example a follow-up query may need to load a subset of the same data loaded by the initial query, putting additional pressure on data stores.

## Prefetching
This technique involves optimistically fetching data based on a prediction that a user will execute an action. Prefetching can be one of the most effective ways of reducing latency. However, a significant tradeoff with prefetching that a lot of applications cannot afford is **increased server cost due to incorrect predictions.** With an unsophisticated prefetch algorithm, applications can easily overfetch by a factor of 10 fold.

# Proposal: Incrementally deliver data with @defer and @stream

This proposal would introduce @stream and @defer directives which clients could use to communicate the relative priority of requested data to GraphQL implementations. Furthermore this proposal would enable GraphQL APIs to split requested data across multiple response payloads in order of priority. The goal of this proposal is to enable applications to reduce latency without increasing server cost or resource contention.

```
// Example Query with @defer and @stream.
{
  viewer {
     friends(first: 2) @stream(initial_count: 1) {
	 id
     }
  }
  … GroupAdminFragment @defer
}

fragment GroupAdminFragment {
   managed_groups {
      id
   }
}

// Response payloads

// payload 1
{
  path: [“viewer”, “friends”, 1],
  data: {id: 4}
}

// payload 2
{
  path: [“viewer”, “friends”, 2],
  data: {id: 5}
}

// payload 3
{
  path: [“viewer”],
  data: {managed_groups: [{id: 1, id: 2}]}
  extensions: {is_final: true}
}
```
While both incremental delivery and GraphQL subscriptions send multiple payloads over time, **incremental delivery is _not_ intended to enable applications to respond to real-time changes.** Consequently streams opened for incremental delivery are expected to be short-lived. **Implementations are not required to reflect interleaving mutations which occur during incremental delivery.** Assuming there are no interleaving mutations, combining together the various payloads in an incrementally delivered response should produce the same output as if that response was not delivered incrementally.

Facebook has been using Incremental Delivery at scale since 2017, including on major surfaces such as news feed. This proposal captures the key concepts that we have found to be useful. 


## Benefits of incremental delivery
* Make GraphQL a great choice for applications which demand responsiveness
* Enable interoperability between different GraphQL clients and servers without restricting implementation.
* Enable a strong tooling ecosystem (including GraphiQL).
* Provide concrete guidance to implementers
* Provide guidance to developers evaluating whether to adopt incremental delivery

The following is a list of incremental delivery concepts:
* @defer: a directive specified on a fragment spread to imply de-prioritization, that causes the fragment to be omitted in the initial response, and delivered as a subsequent response afterward.
* @stream: a directive specified on a List type field that implies prioritization of the minimum data required and de-prioritization of data completeness.
* Path: a list of keys (with plural indexes) from the root of the response to the insertion point that informs the client how to patch a subsequent delta payload into the original payload.
* “is_final” : true entry in the last payload under “extensions” of an incremental delivery request.

## Use case guidance:
The goal of incremental delivery is to prioritize the delivery of essential data. Even though incremental delivery delivers data over time, the response describes the data at a particular point in time. Therefore, it is not necessary to reflect real time changes to the data model in incremental delivery. Implementers of @defer and @stream are not obligated to address interleaving mutations during the execution of @defer and @stream. 

GraphQL Subscription is an event-oriented approach to capture real time data changes. It intends to describe interesting events that happen over a period of time and delivers updated value that “invalidate” previous values.

## Implementation details of @stream and @defer

For GraphQL communications built on top of HTTP, a natural and compatible technology to leverage is HTTP chunked encoding to implement a stream of responses for incremental delivery.



# Additional material
- [1] [Lee Byron on idea of @defer and @stream](https://www.youtube.com/watch?v=ViXL0YQnioU&feature=youtu.be&t=9m4s)
- [2] [[Proposal] Introducing @defer in Apollo Server](https://blog.apollographql.com/introducing-defer-in-apollo-server-f6797c4e9d6e)
- [3] [Active development on @defer and @stream in Relay at Facebook](https://github.com/graphql/graphql-wg/issues/329)
