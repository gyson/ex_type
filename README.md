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
    {:ex_type, "~> 0.1.0"}
  ]
end
```

Documentation can be found at [https://hexdocs.pm/ex_type](https://hexdocs.pm/ex_type).

## Development Note

- Use `MIX_ENV=test iex -S mix` to access test context.

## License

MIT
