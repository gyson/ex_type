defmodule ExType.TypespecTest do
  use ExUnit.Case

  alias ExType.Type
  alias ExType.Typespec

  @any_type %Type.Any{}
  @true_type %Type.Atom{literal: true, value: true}
  @false_type %Type.Atom{literal: true, value: false}

  test "union_types should be sorted" do
    union_type_1 =
      Typespec.union_types([
        @true_type,
        @false_type
      ])

    union_type_2 =
      Typespec.union_types([
        @false_type,
        @true_type
      ])

    assert union_type_1 == union_type_2
  end

  test "union_types may convert to any() type" do
    union_type =
      Typespec.union_types([
        @true_type,
        @false_type,
        @any_type
      ])

    assert union_type == @any_type
  end
end
