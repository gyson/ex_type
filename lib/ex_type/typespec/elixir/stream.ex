import ExType.Typespec, only: [deftypespec: 2]

deftypespec Stream do
  @spec chunk_by(T.p(Enumerable, x), (x -> any())) :: T.p(Enumerable, [x]) when x: any()

  @spec chunk_every(T.p(Enumerable, x), pos_integer()) :: T.p(Enumerable, [x]) when x: any()

  @spec chunk_every(T.p(Enumerable, x), pos_integer(), pos_integer()) :: T.p(Enumerable, [x])
        when x: any()

  @spec chunk_every(
          T.p(Enumerable, x),
          pos_integer(),
          pos_integer(),
          T.p(Enumerable, x) | :discard
        ) :: T.p(Enumerable, [x])
        when x: any()

  @spec concat(T.p(Enumerable, T.p(Enumerable, x))) :: T.p(Enumerable, x) when x: any()

  @spec concat(T.p(Enumerable, x), T.p(Enumerable, y)) :: T.p(Enumerable, x | y)
        when x: any(), y: any()

  @spec cycle(T.p(Enumerable, x)) :: T.p(Enumerable, x) when x: any()

  @spec dedup(T.p(Enumerable, x)) :: T.p(Enumerable, x) when x: any()

  @spec dedup_by(T.p(Enumerable, x), (x -> any())) :: T.p(Enumerable, x) when x: any()

  @spec drop(T.p(Enumerable, x), non_neg_integer()) :: T.p(Enumerable, x) when x: any()

  @spec drop_every(T.p(Enumerable, x), non_neg_integer()) :: T.p(Enumerable, x) when x: any()

  @spec drop_while(T.p(Enumerable, x), (x -> boolean())) :: T.p(Enumerable, x) when x: any()

  @spec each(T.p(Enumerable, x), (x -> any())) :: :ok when x: any()

  @spec filter(T.p(Enumerable, x), (x -> boolean())) :: T.p(Enumerable, x) when x: any()

  @spec flat_map(T.p(Enumerable, x), (x -> T.p(Enumerable, y))) :: T.p(Enumerable, y)
        when x: any(), y: any()

  @spec intersperse(T.p(Enumerable, x), y) :: T.p(Enumerable, x | y) when x: any(), y: any()

  @spec interval(non_neg_integer()) :: T.p(Enumerable, non_neg_integer())

  @spec into(T.p(Enumerable, x), T.p(Collectable, x)) :: T.p(Enumerable, x) when x: any()

  @spec into(T.p(Enumerable, x), T.p(Collectable, y), (x -> y)) :: T.p(Enumerable, x)
        when x: any(), y: any()

  @spec iterate(x, (x -> x)) :: T.p(Enumerable, x) when x: any()

  @spec map(T.p(Enumerable, x), (x -> y)) :: T.p(Enumerable, y) when x: any(), y: any()

  @spec map_every(T.p(Enumerable, x), non_neg_integer(), (x -> y)) :: T.p(Enumerable, x | y)
        when x: any(), y: any()

  @spec reject(T.p(Enumerable, x), (x -> boolean())) :: T.p(Enumerable, x) when x: any()

  @spec repeatedly((() -> x)) :: T.p(Enumerable, x) when x: any()

  @spec resource(
          (() -> acc),
          (acc -> {[x], acc} | {:halt, acc}),
          (acc -> any())
        ) :: T.p(Enumerable, x)
        when x: any(), acc: any()

  @spec run(T.p(Enumerable, any())) :: :ok

  @spec scan(T.p(Enumerable, x), (x, x -> x)) :: T.p(Enumerable, x) when x: any()

  @spec scan(T.p(Enumerable, x), x, (x, x -> x)) :: T.p(Enumerable, x) when x: any()

  @spec take(T.p(Enumerable, x), integer()) :: T.p(Enumerable, x) when x: any()

  @spec take_every(T.p(Enumerable, x), non_neg_integer()) :: T.p(Enumerable, x) when x: any()

  @spec take_while(T.p(Enumerable, x), (x -> boolean())) :: T.p(Enumerable, x) when x: any()

  @spec timer(non_neg_integer()) :: T.p(Enumerable, integer())

  @spec transform(T.p(Enumerable, x), acc, (x, acc -> {T.p(Enumerable, y), acc} | {:halt, acc})) ::
          T.p(Enumerable, y)
        when x: any(), y: any(), acc: any()

  @spec transform(
          T.p(Enumerable, x),
          acc,
          (x, acc -> {T.p(Enumerable, y), acc} | {:halt, acc}),
          (acc -> any())
        ) :: T.p(Enumerable, y)
        when x: any(), y: any(), acc: any()

  @spec unfold(acc, (acc -> {x, acc} | nil)) :: T.p(Enumerable, x) when x: any()

  @spec uniq(T.p(Enumerable, x)) :: T.p(Enumerable, x) when x: any()

  @spec uniq_by(T.p(Enumerable, x), (x -> any())) :: T.p(Enumerable, x) when x: any()

  @spec with_index(T.p(Enumerable, x)) :: T.p(Enumerable, {x, integer()}) when x: any()

  @spec with_index(T.p(Enumerable, x), integer()) :: T.p(Enumerable, {x, integer()}) when x: any()

  @spec zip([T.p(Enumerable, any())]) :: T.p(Enumerable, tuple())

  @spec zip(T.p(Enumerable, x), T.p(Enumerable, y)) :: T.p(Enumerable, {x, y})
        when x: any(), y: any()
end
