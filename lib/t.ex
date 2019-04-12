defmodule T do
  # TODO: make it as an independent library
  # T is a runtime dependency
  # ExType is a dev dependency

  @moduledoc """
  Minimal runtime support for ExType
  """

  # usage: T.&({a, b, c, d})
  # note: use `x | any()` instead of `any()` to avoid compiler error
  @type (&x) :: any() | x

  # usage, when implement Enumerable for map
  # @type t :: T.impl(%{k => v}, {k, v})
  @type impl(x, y) :: any() | x | y

  # usage: T.opaque()
  @type opaque() :: any()

  # usage: T.opaque(x) or T.opaque({a, b, c})
  @type opaque(x) :: any() | x

  # T.p(Enumerable.t, x)
  # equvalent to Enumerable.t(x)
  # shortcut for protocol
  @type p(x, y) :: any() | x | y

  @doc false
  defmacro __using__(_opts) do
    quote do
      import T, only: [{:~>, 2}]
    end
  end

  @doc """
  Inline type annotation support.

  ## Example

      x ~> integer() = get(:something)

      [1, 2, 3]
      |> Enum.map(fn x -> get(x) end)
      |> T.~>([number]) # hint
      |> Enum.filter(fn x ->
        ...
      end)

  """
  defmacro x ~> _type do
    quote(do: unquote(x))
  end

  @doc """
  Inspect type while doing type checking.

  ## Example

      T.inspect {x, y}

  """
  defmacro inspect(x, _opts \\ []) do
    quote(do: unquote(x))
  end

  @doc """
  Assert type while doing type checking.

  ## Example

      x = 10
      T.assert x == integer()

  """
  defmacro assert(_expr, _message \\ "") do
    quote(do: nil)
  end
end
