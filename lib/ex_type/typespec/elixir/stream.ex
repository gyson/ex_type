import ExType.Typespec, only: [deftypespec: 2]

deftypespec Stream do
  @spec map(T.p(Enumerable.t(), x), (x -> y)) :: T.p(Enumerable.t(), y) when x: any(), y: any()

  @spec filter(T.p(Enumerable.t(), x), (x -> boolean())) :: T.p(Enumerable.t(), x) when x: any()

  @spec flat_map(T.p(Enumerable.t(), x), (x -> T.p(Enumerable.t(), y))) :: T.p(Enumerable.t(), y)
        when x: any(), y: any()
end
