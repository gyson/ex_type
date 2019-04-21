import ExType.Typespec, only: [deftypespec: 2]

deftypespec Map do
  @type t(key, value) :: %{optional(key) => value}

  @spec delete(t(k, v), k) :: t(k, v) when k: any(), v: any()

  @spec drop(t(k, v), T.p(Enumerable, k)) :: t(k, v) when k: any(), v: any()

  @spec equal?(map(), map()) :: boolean()

  @spec fetch(t(k, v), k) :: {:ok, v} | :error when k: any(), v: any()

  @spec fetch!(t(k, v), k) :: v when k: any(), v: any()

  @spec from_struct(atom() | struct()) :: map()

  @spec get(t(k, v), k) :: v | nil when k: any(), v: any()

  @spec get(t(k, v), k, default) :: v | default when k: any(), v: any(), default: any()

  @spec get_and_update(t(k, v), k, (v -> {get, v} | :pop)) :: {get, t(k, v)}
        when k: any(), v: any(), get: any()

  @spec get_and_update!(t(k, v), k, (v -> {get, v} | :pop)) :: {get, t(k, v)}
        when k: any(), v: any(), get: any()

  @spec get_lazy(t(k, v), k, (() -> v)) :: v when k: any(), v: any()

  @spec has_key?(t(k, v), k) :: boolean() when k: any(), v: any()

  @spec keys(t(k, v)) :: [k] when k: any(), v: any()

  @spec merge(t(k, v), t(k, v)) :: t(k, v) when k: any(), v: any()

  @spec merge(t(k, v), t(k, v), (k, v, v -> v)) :: t(k, v) when k: any(), v: any()

  @spec new() :: %{}

  @spec new(T.p(Enumerable, {x, y})) :: t(x, y) when x: any(), y: any()

  @spec new(T.p(Enumerable, x), (x -> {y, z})) :: t(x, y) when x: any(), y: any(), z: any()

  @spec pop(t(k, v), k) :: {v | nil, t(k, v)} when k: any(), v: any()

  @spec pop(t(k, v), k, default) :: {v | default, t(k, v)} when k: any(), v: any(), default: any()

  @spec pop_lazy(t(k, v), k, (() -> v)) :: {v, t(k, v)} when k: any(), v: any()

  @spec put(t(k, v), k, v) :: t(k, v) when k: any(), v: any()

  @spec put_new(t(k, v), k, v) :: t(k, v) when k: any(), v: any()

  @spec put_new_lazy(t(k, v), k, (() -> v)) :: t(k, v) when k: any(), v: any()

  @spec replace!(t(k, v), k, v) :: t(k, v) when k: any(), v: any()

  @spec split(t(k, v), T.p(Enumerable, k)) :: {t(k, v), t(k, v)} when k: any(), v: any()

  @spec take(t(k, v), T.p(Enumerable, k)) :: t(k, v) when k: any(), v: any()

  @spec to_list(t(k, v)) :: [{k, v}] when k: any(), v: any()

  @spec udpate(t(k, v), k, v, (v -> v)) :: t(k, v) when k: any(), v: any()

  @spec update!(t(k, v), k, (v -> v)) :: t(k, v) when k: any(), v: any()

  @spec values(t(k, v)) :: [v] when k: any(), v: any()
end
