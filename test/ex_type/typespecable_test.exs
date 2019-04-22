defmodule ExType.TypespecableTest do
  use ExUnit.Case

  alias ExType.Type
  alias ExType.Typespecable

  test "any" do
    assert Typespecable.to_quote(%Type.Any{}) == quote(do: any())
  end

  test "number" do
    assert Typespecable.to_quote(%Type.Integer{}) == quote(do: integer())
    assert Typespecable.to_quote(%Type.Float{}) == quote(do: float())
  end

  test "atom" do
    assert Typespecable.to_quote(%Type.Atom{literal: true, value: :x}) == quote(do: :x)
  end

  test "function" do
    any_type = %Type.Any{}

    assert Typespecable.to_quote(%Type.TypedFunction{inputs: [], output: any_type}) ==
             quote(do: (() -> any()))

    assert Typespecable.to_quote(%Type.TypedFunction{inputs: [any_type], output: any_type}) ==
             quote(do: (any() -> any()))

    assert Typespecable.to_quote(%Type.TypedFunction{
             inputs: [any_type, any_type],
             output: any_type
           }) ==
             quote(do: (any(), any() -> any()))

    integer = %Type.Integer{}

    typed_fn = %Type.TypedFunction{
      inputs: [integer, integer],
      output: integer
    }

    assert Typespecable.to_quote(typed_fn) == quote(do: (integer(), integer() -> integer()))
  end

  test "tuple" do
    assert Typespecable.to_quote(%Type.TypedTuple{types: [%Type.Any{}]}) == quote(do: {any()})
  end
end
