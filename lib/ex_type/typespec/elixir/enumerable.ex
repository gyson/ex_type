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
  @spec ex_type_impl([x]) :: x when x: any()
end

deftypespec Enumerable.Map do
  @spec ex_type_impl(%{required(k) => v}) :: {k, v} when k: any(), v: any()
end

deftypespec Enumerable.MapSet do
  @spec ex_type_impl(MapSet.t(x)) :: x when x: any()
end

deftypespec Enumerable.Range do
  # TODO
end

deftypespec Enumerable.Stream do
  # TODO
end
