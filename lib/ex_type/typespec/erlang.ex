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

  @spec binary_to_term(binary()) :: any()
end
