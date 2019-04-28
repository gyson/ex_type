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
    {:ex_type, "~> 0.2.0", only: :dev, runtime: false},

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

## Development Note

- Use `MIX_ENV=test iex -S mix` to access test context.

## License

MIT
