defmodule ExTypeTest do
  @moduledoc """
  Test whether ex_type can successfully typecheck files without crashing.
  """

  use ExUnit.Case
  import ExUnit.CaptureIO

  alias ExType.Emoji

  doctest ExType

  for file <- Path.wildcard("#{__DIR__}/type_checks/**/*.ex") do
    test "type check test case #{file}" do
      result = capture_io(fn -> ExType.check(unquote(file)) end)
      assert String.contains?(result, [Emoji.one_test_pass()])
      refute String.contains?(result, [Emoji.one_test_fail()])
    end
  end

  for file <- Path.wildcard("#{__DIR__}/type_failures/**/*.ex") do
    test "type check failure case #{file}" do
      result = capture_io(fn -> ExType.check(unquote(file)) end)
      refute String.contains?(result, [Emoji.one_test_pass()])
      assert String.contains?(result, [Emoji.one_test_fail()])
    end
  end
end
