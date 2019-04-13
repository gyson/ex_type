defmodule ExTypeTest do
  use ExUnit.Case
  doctest ExType

  test "enumerable should works" do
    ExType.check("#{__DIR__}/ex_type/enumerable_test_case.ex")
  end

  test "stream should works" do
    ExType.check("#{__DIR__}/ex_type/stream_test_case.ex")
  end
end
