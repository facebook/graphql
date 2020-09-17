# Appendix: Schema Coordinates

Schema Coordinates are human readable strings that uniquely identify an element defined in a GraphQL Schema.

## Definition 

SchemaCoordinates :
  - TypeName FieldSpecifier?
  - InterfaceName FieldSpecifier?
  - EnumName EnumValueSpecifier?
  - @ DirectiveName ArgumentSpecifier?
  - UnionName

FieldSpecifier :
  - . FieldName ArgumentSpecifier?

ArgumentSpecifier :
  - ( ArgumentName )

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

**Selecting a Type**

Schema Coordinates for the `Business` type:

```example
Business
```

Schema Coordinates for the `User` type:

```example
User
```

**Selecting a Field on a Type**

Schema Coordinates for the `name` field on the `Business` type:

```example
Business.name
```

Schema Coordinates for the `name` field on the `User` type:

```example
User.name
```

**Selecting an Argument on a Field**

Schema Coordinates for the `name` argument on the `searchBusiness` field on the `Query` type:

```example
Query.searchBusiness(name)
```

Schema Coordinates for the `filter` argument on the `searchBusiness` field on the `Query` type:

```example
Query.searchBusiness(filter)
```

**Selecting an Enum**

Schema Coordinates for the `SearchFilter` enum:

```example
SearchFilter
```

**Selecting an Enum Value**

Schema Coordinates for the `OPEN_NOW` value of the`SearchFilter` enum:

```example
SearchFilter.OPEN_NOW
```

**Selecting a Directive Definition**

Schema Coordinates for the `@private` directive definition:

```example
@private
```

**Selecting a Directive Definition Argument**

Schema Coordinates for the `scope` argument on the `@private` directive definition:

```example
@private(scope)
```

**Selecting an Interface**

Schema Coordinates for the `Address` interface:

```example
Address
```

**Selecting a Field on an Interface**

Schema Coordinates for the `city` field on the `Address` interface:

```example
Address.city
```

**Selecting a Union**

Schema Coordinates for the `Entity` union definition:

```example
Entity
```

You may not select members inside a union definition.

```graphql counter-example
Entity.Business
```

In such cases, you may wish to [select the type directly](#sec-Examples.Selecting-a-Type) instead.