import ExType.Typespec, only: [deftypespec: 2]

deftypespec Collectable do
  # TODO
end

deftypespec Collectable.BitString do
  # TODO
end

deftypespec Collectable.File.Stream do
  # TODO
end

deftypespec Collectable.IO.Stream do
  # TODO
end

deftypespec Collectable.List do
  @type t(x) :: T.impl([x], x)
end

deftypespec Collectable.Map do
  @type t(k, v) :: T.impl(%{required(k) => v}, {k, v})
end

deftypespec Collectable.MapSet do
  @type t(x) :: T.impl(MapSet.t(x), x)
end
