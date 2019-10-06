defmodule ExType.ArgumentExpanderTest do
  use ExUnit.Case

  alias ExType.{ArgumentExpander, Type}

  defp assert_equal(left, right) when is_list(left) and is_list(right) do
    assert Enum.sort(left) == Enum.sort(right)
  end

  test "expand_union_types/1 with empty args" do
    assert_equal(ArgumentExpander.expand_union_types([]), [])
  end

  test "expand_union_types/1 with one arg" do
    assert_equal(ArgumentExpander.expand_union_types([Type.any()]), [[Type.any()]])

    assert_equal(
      ArgumentExpander.expand_union_types([
        Type.union([Type.integer(), Type.float()])
      ]),
      [[Type.integer()], [Type.float()]]
    )
  end

  test "expand_union_types/1 with multiple args" do
    assert_equal(
      ArgumentExpander.expand_union_types([
        Type.union([Type.integer(), Type.float()]),
        Type.union([Type.integer(), Type.float()]),
        Type.any()
      ]),
      [
        [Type.integer(), Type.integer(), Type.any()],
        [Type.integer(), Type.float(), Type.any()],
        [Type.float(), Type.float(), Type.any()],
        [Type.float(), Type.integer(), Type.any()]
      ]
    )
  end
end
