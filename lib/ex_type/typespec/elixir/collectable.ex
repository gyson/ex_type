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
  @spec ex_type_impl([x]) :: x when x: any()
end

deftypespec Collectable.Map do
  @spec ex_type_impl(%{required(k) => v}) :: {k, v} when k: any(), v: any()
end

deftypespec Collectable.MapSet do
  @spec ex_type_impl(MapSet.t(x)) :: x when x: any()
end
