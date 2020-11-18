# Appendix: Schema Coordinates

Schema Coordinates are human readable strings that uniquely identify an element defined in a GraphQL Schema.

## Definition 

SchemaCoordinates :
  - TypeDefinitionName FieldSpecifier?
  - EnumName EnumValueSpecifier?
  - @ DirectiveName ArgumentSpecifier?
  - UnionName

TypeDefinitionName:
  - ObjectTypeName
  - InterfaceTypeName

FieldSpecifier :
  - . FieldName ArgumentSpecifier?

ArgumentSpecifier :
  - ( ArgumentName: )

EnumValueSpecifier :
  - . EnumValue

## Examples

This section shows example coordinates for the possible schema element types this syntax covers.

All examples below will assume the following schema:

```graphql example
directive @private(scope: String!) on FIELD

interface Address {
    city: String
}

type User implements Address {
    name: String
    reviewCount: Int
    friends: [User]
    email: String @private(scope: 'loggedIn')
    city: String
}

type Business implements Address {
    name: String
    address: String
    rating: Int
    city: String
}

union Entity = User | Business

enum SearchFilter {
    OPEN_NOW
    DELIVERS_TAKEOUT
    VEGETARIAN_MENU
}

type Query {
    searchBusiness(name: String!, filter: SearchFilter): Business
}
```

The following table demonstrates how to select various kinds of schema elements:

|  Example                       | Description                                                         |
| ------------------------------ | ------------------------------------------------------------------- |
| `Business`                     | `Business` type                                                     |
| `User`                         | `User` type                                                         |
| `Business.name`                | `name` field on the `Business` type                                 |
| `User.name`                    | `name` field on the `User` type                                     |
| `Query.searchBusiness(name:)`  | `name` argument on the `searchBusiness` field on the `Query` type   |
| `Query.searchBusiness(filter:)`| `filter` argument on the `searchBusiness` field on the `Query` type |
| `SearchFilter`                 | `SearchFilter` enum                                                 |
| `SearchFilter.OPEN_NOW`        | `OPEN_NOW` value of the`SearchFilter` enum                          |
| `@private`                     | `@private` directive definition                                     |
| `@private(scope:)`             | `scope` argument on the `@private` directive definition             |
| `Address`                      | `Address` interface                                                 |
| `Address.city`                 | `city` field on the `Address` interface                             |
| `Entity`                       | `Entity` union definition                                           |

Note: You may not select members inside a union definition.

The following counter example are *not* considered valid Schema Coordinates:

```graphql counter-example
Entity.Business
```

In such cases, you may wish to select the type directly instead (e.g. `Business`).