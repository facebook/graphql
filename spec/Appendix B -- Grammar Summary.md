# B. Appendix: Grammar Summary

## Source Text

SourceCharacter ::
  - "Any Unicode scalar value"


## Ignored Tokens

Ignored ::
  - UnicodeBOM
  - WhiteSpace
  - LineTerminator
  - Comment
  - Comma

UnicodeBOM :: "Byte Order Mark (U+FEFF)"

WhiteSpace ::
  - "Horizontal Tab (U+0009)"
  - "Space (U+0020)"

LineTerminator ::
  - "New Line (U+000A)"
  - "Carriage Return (U+000D)" [lookahead != "New Line (U+000A)"]
  - "Carriage Return (U+000D)" "New Line (U+000A)"

Comment :: `#` CommentChar* [lookahead != CommentChar]

CommentChar :: SourceCharacter but not LineTerminator

Comma :: ,


## Lexical Tokens

Token ::
  - Punctuator
  - Name
  - IntValue
  - FloatValue
  - StringValue

Punctuator :: one of ! $ & ( ) ... : = @ [ ] { | }

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

IntValue :: IntegerPart [lookahead != {Digit, `.`, NameStart}]

IntegerPart ::
  - NegativeSign? 0
  - NegativeSign? NonZeroDigit Digit*

NegativeSign :: -

NonZeroDigit :: Digit but not `0`

FloatValue ::
  - IntegerPart FractionalPart ExponentPart [lookahead != {Digit, `.`, NameStart}]
  - IntegerPart FractionalPart [lookahead != {Digit, `.`, NameStart}]
  - IntegerPart ExponentPart [lookahead != {Digit, `.`, NameStart}]

FractionalPart :: . Digit+

ExponentPart :: ExponentIndicator Sign? Digit+

ExponentIndicator :: one of `e` `E`

Sign :: one of + -

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

Note: Block string values are interpreted to exclude blank initial and trailing
lines and uniform indentation with {BlockStringValue()}.


## Document Syntax

Document : Definition+

Definition :
  - ExecutableDefinition
  - TypeSystemDefinitionOrExtension

ExecutableDocument : ExecutableDefinition+

ExecutableDefinition :
  - OperationDefinition
  - FragmentDefinition

OperationDefinition :
  - OperationType Name? VariableDefinitions? Directives? SelectionSet
  - SelectionSet

OperationType : one of `query` `mutation` `subscription`

SelectionSet : { Selection+ }

Selection :
  - Field
  - FragmentSpread
  - InlineFragment

Field : Alias? Name Arguments? Directives? SelectionSet?

Alias : Name :

Arguments[Const] : ( Argument[?Const]+ )

Argument[Const] : Name : Value[?Const]

FragmentSpread : ... FragmentName Directives?

InlineFragment : ... TypeCondition? Directives? SelectionSet

FragmentDefinition : fragment FragmentName TypeCondition Directives? SelectionSet

FragmentName : Name but not `on`

TypeCondition : on NamedType

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

BooleanValue : one of `true` `false`

NullValue : `null`

EnumValue : Name but not `true`, `false` or `null`

ListValue[Const] :
  - [ ]
  - [ Value[?Const]+ ]

ObjectValue[Const] :
  - { }
  - { ObjectField[?Const]+ }

ObjectField[Const] : Name : Value[?Const]

VariableDefinitions : ( VariableDefinition+ )

VariableDefinition : Variable : Type DefaultValue? Directives[Const]?

Variable : $ Name

DefaultValue : = Value[Const]

Type :
  - NamedType
  - ListType
  - NonNullType

NamedType : Name

ListType : [ Type ]

NonNullType :
  - NamedType !
  - ListType !

Directives[Const] : Directive[?Const]+

Directive[Const] : @ Name Arguments[?Const]?

TypeSystemDocument : TypeSystemDefinition+

TypeSystemDefinition :
  - SchemaDefinition
  - TypeDefinition
  - DirectiveDefinition

TypeSystemExtensionDocument : TypeSystemDefinitionOrExtension+

TypeSystemDefinitionOrExtension :
  - TypeSystemDefinition
  - TypeSystemExtension

TypeSystemExtension :
  - SchemaExtension
  - TypeExtension

SchemaDefinition : Description? schema Directives[Const]? { RootOperationTypeDefinition+ }

SchemaExtension :
  - extend schema Directives[Const]? { RootOperationTypeDefinition+ }
  - extend schema Directives[Const] [lookahead != `{`]

RootOperationTypeDefinition : OperationType : NamedType

Description : StringValue

TypeDefinition :
  - ScalarTypeDefinition
  - ObjectTypeDefinition
  - InterfaceTypeDefinition
  - UnionTypeDefinition
  - EnumTypeDefinition
  - InputObjectTypeDefinition

TypeExtension :
  - ScalarTypeExtension
  - ObjectTypeExtension
  - InterfaceTypeExtension
  - UnionTypeExtension
  - EnumTypeExtension
  - InputObjectTypeExtension

ScalarTypeDefinition : Description? scalar Name Directives[Const]?

ScalarTypeExtension :
  - extend scalar Name Directives[Const]

ObjectTypeDefinition :
  - Description? type Name ImplementsInterfaces? Directives[Const]? FieldsDefinition
  - Description? type Name ImplementsInterfaces? Directives[Const]? [lookahead != `{`]

ObjectTypeExtension :
  - extend type Name ImplementsInterfaces? Directives[Const]? FieldsDefinition
  - extend type Name ImplementsInterfaces? Directives[Const] [lookahead != `{`]
  - extend type Name ImplementsInterfaces [lookahead != `{`]

ImplementsInterfaces :
  - ImplementsInterfaces & NamedType
  - implements `&`? NamedType

FieldsDefinition : { FieldDefinition+ }

FieldDefinition : Description? Name ArgumentsDefinition? : Type Directives[Const]?

ArgumentsDefinition : ( InputValueDefinition+ )

InputValueDefinition : Description? Name : Type DefaultValue? Directives[Const]?

InterfaceTypeDefinition :
  - Description? interface Name ImplementsInterfaces? Directives[Const]? FieldsDefinition
  - Description? interface Name ImplementsInterfaces? Directives[Const]? [lookahead != `{`]

InterfaceTypeExtension :
  - extend interface Name ImplementsInterfaces? Directives[Const]? FieldsDefinition
  - extend interface Name ImplementsInterfaces? Directives[Const] [lookahead != `{`]
  - extend interface Name ImplementsInterfaces [lookahead != `{`]

UnionTypeDefinition : Description? union Name Directives[Const]? UnionMemberTypes?

UnionMemberTypes :
  - UnionMemberTypes | NamedType
  - = `|`? NamedType

UnionTypeExtension :
  - extend union Name Directives[Const]? UnionMemberTypes
  - extend union Name Directives[Const]

EnumTypeDefinition :
  - Description? enum Name Directives[Const]? EnumValuesDefinition
  - Description? enum Name Directives[Const]? [lookahead != `{`]

EnumValuesDefinition : { EnumValueDefinition+ }

EnumValueDefinition : Description? EnumValue Directives[Const]?

EnumTypeExtension :
  - extend enum Name Directives[Const]? EnumValuesDefinition
  - extend enum Name Directives[Const] [lookahead != `{`]

InputObjectTypeDefinition :
  - Description? input Name Directives[Const]? InputFieldsDefinition
  - Description? input Name Directives[Const]? [lookahead != `{`]

InputFieldsDefinition : { InputValueDefinition+ }

InputObjectTypeExtension :
  - extend input Name Directives[Const]? InputFieldsDefinition
  - extend input Name Directives[Const] [lookahead != `{`]

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
