# ExType

A type checker for Elixir.

## Feature

- gradual typing
- type check for protocol and generic protocol
- type check with intersection and union types
- type guards
- type assertion
- type inspection

## Installation

The package can be installed by adding `ex_type` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    # Required developement dependency
    {:ex_type, "~> 0.4.0", only: :dev, runtime: false},

    # Optional runtime dependency
    {:ex_type_runtime, "~> 0.1.0"}
  ]
end
```

## Rules

To help ExType infer types, following rules are required:

1. All public functions require explicit typespec.

2. All recursive functions require explicit typespec.

Basically, you do not need to add typespec for non-recursive private functions.

## Usage

```sh
# type check for all code
$ mix type

# type check for specified module
$ mix type ExType.Example.Foo

# type check for specified named function
$ mix type ExType.Example.Foo.hello

# type check for named function with specified arity
$ mix type ExType.Example.Foo.hello/0
```

## Example

There are some examples in `lib/ex_type/example/` directory.

## Status

This project is still in very early stage with active development. You are likely to hit
uncovered case when playing more complex code beyond example. Be free to submit github
issue for bug report or any feedback.

## Roadmap

Plan to apply ExType to following small-sized libraries first:

- [x] [Ane](https://github.com/gyson/ane) ([done](https://github.com/gyson/ane/pull/1))
- [x] [Sortable](https://github.com/gyson/sortable) ([done](https://github.com/gyson/sortable/pull/1))
- [x] [Blex](https://github.com/gyson/blex) ([done](https://github.com/gyson/blex/pull/2))
- [ ] [HLL](https://github.com/gyson/hll)
- [ ] [ExType](https://github.com/gyson/ex_type) (probably most challenge one)

## Development Note

- Use `MIX_ENV=test iex -S mix` to access test context.

- It uses serveral Elixir private APIs. It should be ok for now because `ex_type` is
  a development dependency, not a runtime dependency. Would like to reduce private API
  usage at later time when the project is more mature.

## License

MIT
