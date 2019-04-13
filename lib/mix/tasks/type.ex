defmodule Mix.Tasks.Type do
  use Mix.Task

  def run([]) do
    # could run in parallel
    for file <- get_files() do
      ExType.check(file)
    end
  end

  @doc false
  def get_files() do
    cwd = File.cwd!()

    config =
      cwd
      |> Path.join("type.exs")
      |> File.read!()
      |> Code.eval_string()
      |> elem(0)

    includes =
      Keyword.get(config, :only, ["lib/**/*.ex"])
      |> Enum.flat_map(fn glob -> Path.wildcard(Path.join(cwd, glob)) end)
      |> Enum.into(MapSet.new())

    excludes =
      Keyword.get(config, :except, [])
      |> Enum.flat_map(fn glob -> Path.wildcard(Path.join(cwd, glob)) end)
      |> Enum.into(MapSet.new())

    MapSet.difference(includes, excludes)
  end
end
