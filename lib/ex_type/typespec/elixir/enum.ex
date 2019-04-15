import ExType.Typespec, only: [deftypespec: 2]

deftypespec Enum do
  @spec all?(T.p(Enumerable.t(), x)) :: boolean() when x: any()

  @spec all?(T.p(Enumerable.t(), x), (x -> boolean())) :: boolean() when x: any()

  @spec any?(T.p(Enumerable.t(), x)) :: boolean() when x: any()

  @spec any?(T.p(Enumerable.t(), x), (x -> boolean())) :: boolean() when x: any()

  @spec at(T.p(Enumerable.t(), x), integer()) :: x | nil when x: any()

  @spec at(T.p(Enumerable.t(), x), integer(), y) :: x | y when x: any(), y: any()

  @spec map(T.p(Enumerable.t(), x), (x -> y)) :: [y] when x: any(), y: any()

  @spec filter(T.p(Enumerable.t(), x), (x -> boolean())) :: [x] when x: any()

  @spec flat_map(T.p(Enumerable.t(), x), (x -> T.p(Enumerable.t(), y))) :: [y]
        when x: any(), y: any()

  @spec reduce(T.p(Enumerable.t(), x), y, (x, y -> y)) :: y when x: any(), y: any()

  @spec reduce_while(T.p(Enumerable.t(), x), y, (x, y -> {:cont, y} | {:halt, y})) :: y
        when x: any(), y: any()

  @spec join(T.p(Enumerable.t(), binary()), binary()) :: binary()

  @spec zip(T.p(Enumerable.t(), x), T.p(Enumerable.t(), y)) :: [{x, y}] when x: any(), y: any()
end
