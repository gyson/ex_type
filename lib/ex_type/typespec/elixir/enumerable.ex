import ExType.Typespec, only: [deftypespec: 2]

deftypespec Enumerable do
end

deftypespec Enumerable.Date.Range do
  # TODO
end

deftypespec Enumerable.File.Stream do
  # TODO
end

deftypespec Enumerable.Function do
  # TODO
end

deftypespec Enumerable.IO.Stream do
  # TODO
end

deftypespec Enumerable.List do
  @type x :: any()

  @type t :: T.impl([x], x)
end

deftypespec Enumerable.Map do
  @type k :: any()

  @type v :: any()

  @type t :: T.impl(%{required(k) => v}, {k, v})
end

deftypespec Enumerable.MapSet do
  @type x :: any()

  @type t :: T.impl(MapSet.t(x), x)
end

deftypespec Enumerable.Range do
  # TODO
end

deftypespec Enumerable.Stream do
  # TODO
end
