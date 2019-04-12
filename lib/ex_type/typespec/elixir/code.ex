import ExType.Typespec, only: [deftypespec: 2]

deftypespec Code do
  @spec eval_string(binary()) :: {any(), [any()]}
end
