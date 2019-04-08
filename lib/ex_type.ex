defmodule ExType do
  @moduledoc false

  @spec check(binary()) :: any()

  def check(file) do
    [
      "import Kernel, except: [def: 2, defp: 2, defmodule: 2];",
      "import ExType.CustomEnv, only: [def: 2, defmodule: 2];",
      File.read!(file)
    ]
    |> Enum.join("")
    |> Code.eval_string()
  end
end
