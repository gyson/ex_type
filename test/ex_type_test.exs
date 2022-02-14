defmodule ExTypeTest do
  @moduledoc """
  Test whether ex_type can successfully typecheck files without crashing.
  """

  use ExUnit.Case
  import ExUnit.CaptureIO

  alias ExType.Emoji

  doctest ExType

  test "typespec/**/*_test_case.ex" do
    for file <- Path.wildcard("#{__DIR__}/ex_type/**/*_test_case.ex") do
      result = capture_io(fn -> ExType.check(file) end)
      assert String.contains?(result, [Emoji.one_test_pass()])
    end
  end
end
