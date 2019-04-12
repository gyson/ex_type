import ExType.Typespec, only: [deftypespec: 2]

deftypespec Path do
  @spec wildcard(Path.t()) :: [binary()]

  @spec wildcard(Path.t(), [{:match_dot, boolean()}]) :: [binary()]
end
