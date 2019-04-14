defmodule ExTypeTest do
  use ExUnit.Case
  doctest ExType

  test "typespec/**/*.ex" do
    for file <- Path.wildcard("#{__DIR__}/ex_type/typespec/**/*.ex") do
      ExType.check(file)
    end
  end
end
