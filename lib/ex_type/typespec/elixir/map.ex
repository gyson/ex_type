import ExType.Typespec, only: [deftypespec: 2]

deftypespec Map do
  @spec new() :: map()

  @spec new(T.p(Enumerable, {x, y})) :: %{required(x) => y} when x: any(), y: any()

  @spec new(T.p(Enumerable, x), (x -> {y, z})) :: %{required(x) => y}
        when x: any(), y: any(), z: any()
end
