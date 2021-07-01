RFC: Fragment Arguments
-------

# Problem: Variable Modularity

GraphQL fragments are designed to allow a client's data requirements to compose.
Two different screens can use the same underlying UI component.
If that component has a corresponding fragment, then each of those screens can include exactly the data required by having each query spread the child component's fragment.

This modularity begins to break down for variables. As an example, let's imagine a FriendsList component that shows a variable number of friends. We would have a fragment for that component like so:
```
fragment FriendsList on User {
  friends(first: $nFriends) {
    name
  }
}
```

In one use, we might want to show some screen-supplied number of friends, and in another the top 10. For example:
```
fragment AnySizedFriendsList on User {
  name
  ...FriendsList
}

fragment TopFriendsUserProfile on User {
  name
  profile_picture { uri }
  ...FriendsList
}
```

Even though every usage of `TopFriendsUserProfile` should be setting `$nFriends` to `10`, the only way to enforce that is by manually walking all callers of `TopFriendsUserProfile`, recursively, until you arrive at the operation definition and verify the variable is defined like `$nFriends: Int = 10`.

This causes a few major usability problems:
- If I ever want to change the number of items `TopFriendsUserProfile` includes, I now need to update every *operation* that includes it. This could be dozens or hundreds of individual locations.
- Even if the component for `TopFriendsUserProfile` is only able to display 10 friends, in most clients at runtime the user can override the default value, enabling a mismatch between the data required and the data asked for.

# Existing Solution: Relay's `@arguments`/`@argumentDefinitions`

Relay has a solution for this problem by using a custom, non-spec-compliant pair of directives, [`@arguments`/`@argumentDefinitions`](https://relay.dev/docs/api-reference/graphql-and-directives/#arguments).

These directives live only in user-facing GraphQL definitions, and are compiled away prior to making a server request.

Following the above example, if we were using Relay we'd be able to write:
```
fragment FriendsList on User @argumentDefinitions(nFriends: {type: "Int!"}) {
  friends(first: $nFriends) {
    name
  }
}

fragment AnySizedFriendsList on User {
  name
  ...FriendsList @arguments(nFriends: $operationProvidedFriendCount)
}

fragment TopFriendsUserProfile on User {
  name
  profile_picture { uri }
  ...FriendsList @arguments(nFriends: 10)
}
```

Before sending a query to the server, Relay compiles away these directives so the server, when running an operation using `TopFriendsUserProfile`, sees:
```
fragment FriendsList on User {
  friends(first: 10) {
    name
  }
}

fragment TopFriendsUserProfile on User {
  name
  profile_picture { uri }
  ...FriendsList
}
```
The exact mechanics of how Relay rewrites the user-written operation based on `@arguments` supplied is not the focus of this RFC.

However, even to enable this client-compile-time operation transformation, Relay had to introduce *non-compliant directives*: each argument to `@arguments` changes based on the fragment the directive is applied to. While syntactically valid, this fails the [Argument Names validation](https://spec.graphql.org/draft/#sec-Argument-Names).

Additionally, the `@argumentDefinitions` directive gets very verbose and unsafe, using strings to represent variable type declarations.

Relay has supported `@arguments` in its current form since [v2.0](https://github.com/facebook/relay/releases/tag/v2.0.0), released in January 2019. There's now a large body of evidence that allowing fragments to define arguments that can be passed into fragment spreads is a significant usability improvement, and valuable to the wider GraphQL community. However, if we are to introduce this notion more broadly, we should make sure the ergonomics of it conform to users' expectations.

# Proposal: Introduce Fragment Argument Definitions, which allow using arguments on Fragment Spreads

Relay's `@arguments`/`@argumentDefinitions` concepts provide value, and can be applied against GraphQL written for existing GraphQL servers so long as there is a pre-server compiler which transforms the concept away.

## New Fragment Variable Definition syntax

For the `@argumentDefinitions` concept, we can allow fragments to share the same syntax as operation level definitions. Going back to the previous example, this would look like:
```
fragment FriendsList($nFriends: Int!) on User {
  friends(first: $nFriends) {
    name
  }
}
```
This has the advantage of already being supported in `graphql-js`'s AST under an experimental flag, while also

## New Fragment Spread Argument syntax

For the `@arguments` concept, we can allow fragment spreads to share the same syntax as field and directive arguments.
```
fragment AnySizedFriendsList on User {
  name
  ...FriendsList(nFriends: $operationProvidedFriendCount)
}

fragment TopFriendsUserProfile on User {
  name
  profile_picture { uri }
  ...FriendsList(nFriends: 10)
}
```

## New Validation Rule: Fragment Argument Definitions Used in Fragment

The main use case for fragment defined arguments is to make fragments more composable. Therefore, fragments should only be defining variables that are explicitly used under that fragment.

Under this rule,
```
fragment Foo($x: Int) on User {
  name
}
```
would be invalid.

Additionally, under the strictest interpretation of the rule,
```
fragment Foo($x: Int!) on User {
  ...Bar
}

fragment Bar {
  number(x: $x)
}
```
would also be invalid: even though `$x` is used underneath Foo, it is used outside of Foo's explicit definition.

However, this would be valid:
```
fragment Foo($x: Int!) on User {
  ...Bar(x: $x)
}

fragment Bar($x: Int) {
  number(x: $x)
}
```

### Considerations: how strict should this rule be?

As an initial RFC, I'd advocate for encouraging the *strictest* version of this rule possible: any argument defined on a fragment must be explicitly used by that same fragment. It would be easy to relax the rule later, but very difficult to do the reverse.

It's clearly more composable if, when changing a child fragment, you don't need to worry about modifying argument definitions on parent fragments.


## New Validation Rule: Required Fragment Arguments are Provided

Make the [Required Arguments](https://spec.graphql.org/draft/#sec-Required-Arguments) validation's first two bullets:

- For each Field, **Fragment Spread** or Directive in the document.
- Let *arguments* be the set of argument definitions of that Field, **Fragment** or Directive.

With this rule, the below example is invalid, even if the argument `User.number(x:)` is nullable in the schema.
```
fragment Foo on User {
  ...Bar
}

fragment Bar($x: Int!) on User {
  number(x: $x)
}
```


## New Validation Rule: Fragment Argument Uniqueness

If the client pre-server compiler rewrites an operation, it's possible to end up with a selection set that violates [Field Selection Merging](https://spec.graphql.org/draft/#sec-Field-Selection-Merging) validation. Additionally, we have no mechanism on servers today to handle the same fragment having different variable values depending on that fragment's location in an operation.

Therefore, any Fragment Spread for the same Fragment in an Operation must have non-conflicting argument values passed in.

As an example, this is invalid:
```
query {
  user {
    best_friend {
      ...UserProfile(imageSize: 100)
    }
    ...UserProfile(imageSize: 200)
  }
}
```

Note: today Relay's compiler handles this ambiguity. In an extreme simplification, this is done by producing two unique versions of `UserProfile`, where in `UserProfile_0` `$imageSize` is replaced with `100`, and in `UserProfile_1` `$imageSize` is replaced with `200`. However, there exist client implementations that are unable to have multiple applications of the same fragment within a single operation (the clients I work on cannot use Relay's trick).

This validation rule may end up being more strict than required, but it would be easier to relax the rule than make it more strict later.

# Implementation

This proposal can be implemented as a compilation step that compiles the user-written GraphQL into a document without fragment arguments. This can be done in a variety of ways, such as by doing find-variable-replace-with-argument-value or by adding variables on the operation with the argument value set as the default  value.

Alternatively, implementations may want to support fragment arguments directly. For a naive approach, during collectFields, when encountering a fragment spread selection for a fragment with argument definitions, replace the argument variables with the passed in argument value or default values.
