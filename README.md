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

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `ex_type` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_type, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/ex_type](https://hexdocs.pm/ex_type).

## Note

Use `MIX_ENV=test iex -S mix` to access test context.
