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

  # usage: T.opaque()
  @type opaque() :: any()

  # usage: T.opaque(x) or T.opaque({a, b, c})
  @type opaque(x) :: any() | x

  # T.p(Enumerable.t, x)
  # equvalent to Enumerable.t(x)
  # shortcut for protocol
  @type p(x, y) :: any() | x | y

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

      T.assert x :: integer() # cast x as integer when x is like any()

  """
  defmacro assert(_expr, _message \\ "") do
    quote(do: nil)
  end
end
