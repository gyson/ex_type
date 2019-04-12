import ExType.Typespec, only: [deftypespec: 2]

deftypespec MapSet do
  @type t(x) :: T.opaque(x)

  @spec new() :: t(any())

  @spec new(T.p(Enumerable.t(), a)) :: t(a) when a: any()

  @spec new(T.p(Enumerable.t(), a), (a -> b)) :: t(b) when a: any(), b: any()
end
