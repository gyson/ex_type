import ExType.Typespec, only: [deftypespec: 2]

deftypespec :erlang do
  @spec unquote(:+)(integer) :: integer
  @spec unquote(:+)(float) :: float

  @spec unquote(:-)(integer) :: integer
  @spec unquote(:-)(float) :: float

  @spec unquote(:+)(integer, integer) :: integer
  @spec unquote(:+)(integer, float) :: float
  @spec unquote(:+)(float, integer) :: float
  @spec unquote(:+)(float, float) :: float

  @spec unquote(:-)(integer, integer) :: integer
  @spec unquote(:-)(integer, float) :: float
  @spec unquote(:-)(float, integer) :: float
  @spec unquote(:-)(float, float) :: float

  @spec unquote(:*)(integer, integer) :: integer
  @spec unquote(:*)(integer, float) :: float
  @spec unquote(:*)(float, integer) :: float
  @spec unquote(:*)(float, float) :: float

  @spec unquote(:/)(number, number) :: float

  @spec unquote(:>)(any(), any()) :: boolean()
  @spec unquote(:<)(any(), any()) :: boolean()
  @spec unquote(:==)(any(), any()) :: boolean()
  @spec unquote(:"=:=")(any(), any()) :: boolean()
  @spec unquote(:"=<")(any(), any()) :: boolean()
  @spec unquote(:>=)(any(), any()) :: boolean()
  @spec unquote(:"/=")(any(), any()) :: boolean()

  @spec binary_to_term(binary()) :: any()

  @spec error(any()) :: no_return()

  @spec error(any(), [any()]) :: no_return()

  @spec bsl(integer(), integer()) :: integer()

  @spec bor(integer(), integer()) :: integer()

  @spec band(integer(), integer()) :: integer()

  @spec div(integer(), integer()) :: integer()

  @spec rem(integer(), integer()) :: integer()

  @spec phash2(any(), integer()) :: integer()

  @spec max(first, second) :: first | second when first: any(), second: any()
end
