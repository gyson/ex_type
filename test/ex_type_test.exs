defmodule ExTypeTest do
  use ExUnit.Case
  doctest ExType

  test "typespec/**/*_test_case.ex" do
    for file <- Path.wildcard("#{__DIR__}/ex_type/**/*_test_case.ex") do
      ExType.check(file)
    end
  end
end
