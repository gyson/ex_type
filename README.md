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
    {:ex_type, "~> 0.1.2", only: :dev, runtime: false},

    # Optional runtime dependency
    {:ex_type_runtime, "~> 0.1.0"}
  ]
end
```

Documentation can be found at [https://hexdocs.pm/ex_type](https://hexdocs.pm/ex_type).

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

## Development Note

- Use `MIX_ENV=test iex -S mix` to access test context.

## License

MIT
