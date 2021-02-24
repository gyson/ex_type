defmodule ExTypeTest do
  use ExUnit.Case
  doctest ExType

  for file <- Path.wildcard("#{__DIR__}/ex_type/**/*_test_case.ex") do
    test "#{file}" do
      ExType.check(unquote(file))
    end
  end

  for file <- Path.wildcard("#{__DIR__}/ex_type/**/*_failure_case.ex") do
    test "#{file}" do
      ExType.check(unquote(file))
    end
  end
end
