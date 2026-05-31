# Kororā
A tiny & fast composable type system for Nix, in Nix.

Named after the [little penguin](https://www.doc.govt.nz/nature/native-animals/birds/birds-a-z/penguins/little-penguin-korora/).

# Features

- Types
  - Primitive types (`string`, `int`, etc)
  - Polymorphic types (`union`, `attrsOf`, etc)
  - Struct types

# Basic usage

- Verification

Basic verification is done with the type function `verify`:
``` nix
{ korora }:
let
  t = korora.string;

  value = 1;

  # Error contains the string "Expected type 'string' but value '1' is of type 'int'"
  error = t.verify 1;

in if error != null then throw error else value
```
Errors are returned as a string.
On success `null` is returned.

- Checking (assertions)

For convenience you can also check a value on-the-fly:
``` nix
{ korora }:
let
  t = korora.string;

  value = 1;

  # Same error as previous example, but `check` throws.
  value = t.check value value;

in value
```

On error `check` throws. On success it returns the value that was passed in.

# Examples
For usage example see [tests.nix](./tests.nix).

# Reference

## `types.typedef`

Declare a custom type using a bool function

`name`

: Name of the type as a string


`verify`

: Verification function returning a bool.


## `types.typedef'`

Declare a custom type using an optional<string> function.

`name`

: Name of the type as a string


`verify`

: Verification function returning null on success & a string with error message on error.


## `types.typeError`

Basic error function. Used internally, but also useful to throw errors in a
custom type.

`name`

: Name of the type as a string


`v`

: value that failed the type check


## `types.string`

String

## `types.any`

Any

## `types.never`

Never

## `types.int`

Int

## `types.float`

Single precision floating point

## `types.number`

Either an int or a float

## `types.bool`

Bool

## `types.null`

Null

## `types.attrs`

Attribute with undefined attribute types

## `types.list`

Attribute with undefined element types

## `types.function`

Function

## `types.path`

Path

## `types.pathLike`

Value that may not technically be a path, but has path-like properties
Either an actual path `./foo`, a derivation, or a string

## `types.derivation`

Derivation

## `types.type`

Type

## `types.nullOr`

nullOr<t>

`t`

: Null or t


## `types.listOf`

listOf<t>

`t`

: Element type


## `types.attrsOf`

attrsOf<t>

`t`

: Attribute value type


## `types.union`

union<types...>

`types`

: Any of <t>


## `types.intersection`

intersection<types...>

`types`

: All of <t>


## `types.rename`

rename<name, type>

Because some polymorphic types such as attrsOf inherits names from it's
sub-types we need to erase the name to not cause infinite recursion.

#### Example:
``` nix
myType = types.attrsOf (
  types.rename "eitherType" (types.union [
    types.string
    myType
  ])
);
```

`name`

: Function argument


`type`

: Function argument


## `types.struct`

struct<name, members...>

#### Example
``` nix
korora.struct "myStruct" {
  foo = types.string;
}
```

#### Features

- Totality

By default, all attribute names must be present in a struct. It is possible to override this by specifying _totality_. Here is how to do this:
``` nix
(korora.struct "myStruct" {
  foo = types.string;
}).override { total = false; }
```

This means that a `myStruct` struct can have any of the keys omitted. Thus these are valid:
``` nix
let
  s1 = { };
  s2 = { foo = "bar"; }
in ...
```

- Unknown attribute names

By default, unknown attribute names are not allowed.

It is possible to override this by specifying `unknown` on struct creation:
```nix
(korora.struct "myStruct" {
  foo = types.string;
}).override { unknown = true; }
```

This means that
``` nix
{
  foo = "bar";
  baz = "hello";
}
```
is normally invalid, but works when `unknown` is set to `true`.

Because Nix lacks primitive operations to iterate over attribute sets dynamically without
allocation this function allocates one intermediate attribute set per struct verification.

- Custom invariants

Custom struct verification functions can be added as such:
``` nix
(types.struct "testStruct2" {
  x = types.int;
  y = types.int;
}).override {
  verify = v: if v.x + v.y == 2 then "VERBOTEN" else null;
};
```

#### Function signature

`name`

: Name of struct type as a string


`members`

: Attribute set of type definitions.


## `types.optionalAttr`

optionalAttr<t>

## `types.enum`

enum<name, elems...>

`name`

: Name of enum type as a string


`elems`

: List of allowable enum members


## `types.tuple`

tuple<elems...>

`members`

: List of tuple memeber types


## `types.defun`

Create a wrapped type checked function.

`name`

: Function argument


`args`

: Function argument


`T`

: Function argument


`f`

: Function argument



