defmodule ExType.TypespecableTest do
  use ExUnit.Case

  alias ExType.Type
  alias ExType.Typespecable

  test "any" do
    assert Typespecable.to_quote(%Type.Any{}) == quote(do: any())
  end

  test "number" do
    assert Typespecable.to_quote(%Type.Number{kind: :integer}) == quote(do: integer())
    assert Typespecable.to_quote(%Type.Number{kind: :float}) == quote(do: float())
  end

  test "atom" do
    assert Typespecable.to_quote(%Type.Atom{literal: true, value: :x}) == quote(do: :x)
  end

  test "function" do
    assert Typespecable.to_quote(%Type.Function{args: []}) == quote(do: (() -> any()))

    assert Typespecable.to_quote(%Type.Function{args: [1]}) == quote(do: (any() -> any()))

    assert Typespecable.to_quote(%Type.Function{args: [1, 2]}) ==
             quote(do: (any(), any() -> any()))
  end

  test "tuple" do
    assert Typespecable.to_quote(%Type.Tuple{types: [%Type.Any{}]}) == quote(do: {any()})
  end
end
