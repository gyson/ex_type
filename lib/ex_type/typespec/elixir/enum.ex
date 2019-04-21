import ExType.Typespec, only: [deftypespec: 2]

deftypespec Enum do
  @spec all?(T.p(Enumerable, x)) :: boolean() when x: any()

  @spec all?(T.p(Enumerable, x), (x -> boolean())) :: boolean() when x: any()

  @spec any?(T.p(Enumerable, x)) :: boolean() when x: any()

  @spec any?(T.p(Enumerable, x), (x -> boolean())) :: boolean() when x: any()

  @spec at(T.p(Enumerable, x), integer()) :: x | nil when x: any()

  @spec at(T.p(Enumerable, x), integer(), y) :: x | y when x: any(), y: any()

  @spec chunk_by(T.p(Enumerable, x), (x -> any())) :: [[x]] when x: any()

  @spec chunk_every(T.p(Enumerable, x), pos_integer()) :: [[x]] when x: any()

  @spec chunk_every(T.p(Enumerable, x), pos_integer(), pos_integer()) :: [[x]] when x: any()

  @spec chunk_every(
          T.p(Enumerable, x),
          pos_integer(),
          pos_integer(),
          T.p(Enumerable, x) | :discard
        ) :: [[x]]
        when x: any()

  @spec chunk_while(T.p(Enumerable, x), (x -> y)) :: [[x]] when x: any(), y: any()

  @spec concat(T.p(Enumerable, T.p(Enumerable, x))) :: [x] when x: any()

  @spec concat(T.p(Enumerable, x), T.p(Enumerable, y)) :: [x | y] when x: any(), y: any()

  @spec count(T.p(Enumerable, x)) :: non_neg_integer() when x: any()

  @spec count(T.p(Enumerable, x), (x -> boolean())) :: non_neg_integer() when x: any()

  @spec dedup(T.p(Enumerable, x)) :: [x] when x: any()

  @spec dedup_by(T.p(Enumerable, x), (x -> any())) :: [x] when x: any()

  @spec drop(T.p(Enumerable, x), integer()) :: [x] when x: any()

  @spec drop_every(T.p(Enumerable, x), non_neg_integer()) :: [x] when x: any()

  @spec drop_while(T.p(Enumerable, x), (x -> boolean())) :: [x] when x: any()

  @spec each(T.p(Enumerable, x), (x -> any())) :: :ok when x: any()

  @spec empty?(T.p(Enumerable, any())) :: boolean()

  @spec fetch(T.p(Enumerable, x), integer()) :: {:ok, x} | :error when x: any()

  @spec fetch!(T.p(Enumerable, x), integer()) :: x when x: any()

  @spec filter(T.p(Enumerable, x), (x -> boolean())) :: [x] when x: any()

  @spec find(T.p(Enumerable, x), (x -> boolean())) :: x | nil when x: any()

  @spec find(T.p(Enumerable, x), y, (x -> boolean())) :: x | y when x: any(), y: any()

  @spec find_index(T.p(Enumerable, x), (x -> boolean())) :: non_neg_integer() | nil when x: any()

  @spec find_value(T.p(Enumerable, x), (x -> y)) :: y | nil when x: any(), y: any()

  @spec find_value(T.p(Enumerable, x), y, (x -> z)) :: y | z when x: any(), y: any(), z: any()

  @spec flat_map(T.p(Enumerable, x), (x -> T.p(Enumerable, y))) :: [y]
        when x: any(), y: any()

  @spec flat_map_reduce(
          T.p(Enumerable, x),
          acc,
          (x, acc -> {T.p(Enumerable, y), acc} | {:halt, acc})
        ) :: {[y], acc}
        when x: any(), y: any(), acc: any()

  @spec group_by(T.p(Enumerable, x), (x -> y)) :: %{required(x) => [y]} when x: any(), y: any()

  @spec group_by(T.p(Enumerable, x), (x -> y), (x -> z)) :: %{required(x) => [z]}
        when x: any(), y: any(), z: any()

  @spec intersperse(T.p(Enumerable, x), y) :: [x | y] when x: any(), y: any()

  @spec into(T.p(Enumerable, x), T.p(Collectable, x)) :: T.p(Collectable, x)
        when x: any()

  @spec into(T.p(Enumerable, x), T.p(Collectable, y), (x -> y)) :: T.p(Collectable, y)
        when x: any(), y: any()

  @spec join(T.p(Enumerable, String.Chars.t())) :: String.t()

  @spec join(T.p(Enumerable, String.Chars.t()), String.t()) :: String.t()

  @spec map(T.p(Enumerable, x), (x -> y)) :: [y] when x: any(), y: any()

  @spec map_every(T.p(Enumerable, x), non_neg_integer(), (x -> y)) :: [x | y]
        when x: any(), y: any()

  @spec map_join(T.p(Enumerable, x), (x -> String.Chars.t())) :: String.t() when x: any()

  @spec map_join(T.p(Enumerable, x), String.t(), (x -> String.Chars.t())) :: String.t()
        when x: any()

  @spec map_reduce(T.p(Enumerable, x), y, (x, y -> {z, y})) :: {[z], y}
        when x: any(), y: any(), z: any()

  @spec max(T.p(Enumerable, x)) :: x when x: any()

  @spec max(T.p(Enumerable, x), (() -> y)) :: x | y when x: any(), y: any()

  @spec max_by(T.p(Enumerable, x), (x -> any())) :: x when x: any()

  @spec max_by(T.p(Enumerable, x), (x -> any()), (() -> y)) :: x | y when x: any(), y: any()

  @spec member?(T.p(Enumerable, x), x) :: boolean() when x: any()

  @spec min(T.p(Enumerable, x)) :: x when x: any()

  @spec min(T.p(Enumerable, x), (() -> y)) :: x | y when x: any(), y: any()

  @spec min_by(T.p(Enumerable, x), (x -> any())) :: x when x: any()

  @spec min_by(T.p(Enumerable, x), (x -> any()), (() -> y)) :: x | y when x: any(), y: any()

  @spec min_max(T.p(Enumerable, x)) :: {x, x} when x: any()

  @spec min_max(T.p(Enumerable, x), (() -> y)) :: {x, x} | y when x: any(), y: any()

  @spec min_max_by(T.p(Enumerable, x), (x -> y)) :: {x, x} when x: any(), y: any()

  @spec min_max_by(T.p(Enumerable, x), (x -> y), (() -> z)) :: {x, x} | z
        when x: any(), y: any(), z: any()

  @spec random(T.p(Enumerable, x)) :: x when x: any()

  @spec reduce(T.p(Enumerable, x), (x, x -> x)) :: x when x: any()

  @spec reduce(T.p(Enumerable, x), y, (x, y -> y)) :: y when x: any(), y: any()

  @spec reduce_while(T.p(Enumerable, x), y, (x, y -> {:cont, y} | {:halt, y})) :: y
        when x: any(), y: any()

  @spec reject(T.p(Enumerable, x), (x -> boolean())) :: [x] when x: any()

  @spec reverse(T.p(Enumerable, x)) :: [x] when x: any()

  @spec reverse(T.p(Enumerable, x), T.p(Enumerable, y)) :: [x | y] when x: any(), y: any()

  @spec reverse_slice(T.p(Enumerable, x), non_neg_integer(), non_neg_integer()) :: [x]
        when x: any()

  @spec scan(T.p(Enumerable, x), (x, x -> x)) :: [x] when x: any()

  @spec scan(T.p(Enumerable, x), x, (x, x -> x)) :: [x] when x: any()

  @spec shuffle(T.p(Enumerable, x)) :: [x] when x: any()

  @spec slice(T.p(Enumerable, x), Range.t()) :: [x] when x: any()

  @spec slice(T.p(Enumerable, x), integer(), non_neg_integer()) :: [x] when x: any()

  @spec sort(T.p(Enumerable, x)) :: [x] when x: any()

  @spec sort(T.p(Enumerable, x), (x, x -> boolean())) :: [x] when x: any()

  @spec sort_by(T.p(Enumerable, x), (x -> y)) :: [x] when x: any(), y: any()

  @spec sort_by(T.p(Enumerable, x), (x -> y), (y, y -> boolean())) :: [x] when x: any(), y: any()

  @spec split(T.p(Enumerable, x), integer()) :: {[x], [x]} when x: any()

  @spec split_while(T.p(Enumerable, x), (x -> boolean())) :: {[x], [x]} when x: any()

  @spec split_with(T.p(Enumerable, x), (x -> boolean())) :: {[x], [x]} when x: any()

  @spec sum(T.p(Enumerable, number())) :: number()

  @spec take(T.p(Enumerable, x), integer()) :: [x] when x: any()

  @spec take_every(T.p(Enumerable, x), non_neg_integer()) :: [x] when x: any()

  @spec take_random(T.p(Enumerable, x), non_neg_integer()) :: [x] when x: any()

  @spec take_while(T.p(Enumerable, x), (x -> boolean())) :: [x] when x: any()

  @spec to_list(T.p(Enumerable, x)) :: [x] when x: any()

  @spec uniq(T.p(Enumerable, x)) :: [x] when x: any()

  @spec uniq_by(T.p(Enumerable, x), (x -> any())) :: [x] when x: any()

  @spec unzip(T.p(Enumerable, {x, y})) :: {[x], [y]} when x: any(), y: any()

  @spec with_index(T.p(Enumerable, x)) :: [{x, integer()}] when x: any()

  @spec with_index(T.p(Enumerable, x), integer()) :: [{x, integer()}] when x: any()

  @spec zip([T.p(Enumerable, any())]) :: [tuple()]

  @spec zip(T.p(Enumerable, x), T.p(Enumerable, y)) :: [{x, y}] when x: any(), y: any()
end
