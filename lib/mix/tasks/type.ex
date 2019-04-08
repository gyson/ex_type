defmodule Mix.Tasks.Type do
  use Mix.Task

  def run([]) do
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

    files = MapSet.difference(includes, excludes)

    # could run in parallel
    for file <- files do
      ExType.check(file)
    end
  end
end
