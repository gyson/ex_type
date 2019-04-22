import ExType.Typespec, only: [deftypespec: 2]

deftypespec MapSet do
  @spec new() :: MapSet.t(any())

  @spec new(T.p(Enumerable, x)) :: MapSet.t(x) when x: any()

  @spec new(T.p(Enumerable, a), (a -> b)) :: MapSet.t(b) when a: any(), b: any()
end
