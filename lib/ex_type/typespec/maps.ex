import ExType.Typespec, only: [deftypespec: 2]

deftypespec :maps do
  @spec to_list(Map.t(key, value)) :: [{key, value}] when key: any(), value: any()

  @spec values(Map.t(key, value)) :: [value] when key: any(), value: any()
end
