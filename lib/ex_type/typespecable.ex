# Protocol for ExType.Type

alias ExType.Type
alias ExType.Typespec
alias ExType.Typespecable

defprotocol ExType.Typespecable do
  @spec to_quote(Type.t()) :: any()

  def to_quote(x)

  @spec resolve_vars(Type.t(), %{optional(Type.SpecVariable.t()) => Type.t()}) :: Type.t()

  def resolve_vars(x, vars)

  @spec get_protocol_path(Type.t()) :: {:ok, atom()} | :error

  def get_protocol_path(x)
end

defimpl Typespecable, for: Type.Any do
  def to_quote(_) do
    quote do
      any()
    end
  end

  def resolve_vars(type, _) do
    type
  end

  def get_protocol_path(_), do: :error
end

defimpl Typespecable, for: Type.None do
  def to_quote(_) do
    quote do
      none()
    end
  end

  def resolve_vars(type, _) do
    type
  end

  def get_protocol_path(_), do: :error
end

defimpl Typespecable, for: Type.Union do
  def to_quote(%Type.Union{types: types}) do
    [first | rest] = Enum.map(types, &Typespecable.to_quote/1)

    Enum.reduce(rest, first, fn x, acc ->
      quote do
        unquote(x) | unquote(acc)
      end
    end)
  end

  def resolve_vars(%Type.Union{types: types}, vars) do
    Typespec.union_types(Enum.map(types, &Typespecable.resolve_vars(&1, vars)))
  end

  def get_protocol_path(_), do: :error
end

defimpl Typespecable, for: Type.Intersection do
  def to_quote(%Type.Intersection{types: types}) do
    quote do
      T.&({unquote_splicing(Enum.map(types, &Typespecable.to_quote/1))})
    end
  end

  def resolve_vars(%Type.Intersection{types: types}, vars) do
    Typespec.intersect_types(Enum.map(types, &Typespecable.resolve_vars(&1, vars)))
  end

  def get_protocol_path(_), do: :error
end

defimpl Typespecable, for: Type.SpecVariable do
  def to_quote(%Type.SpecVariable{name: name, spec: {module, _, _}}) do
    quote do
      unquote(Macro.var(name, module))
    end
  end

  def resolve_vars(%Type.SpecVariable{} = spec_var, vars) do
    case Map.fetch(vars, spec_var) do
      {:ok, type} ->
        type

      :error ->
        spec_var.type
    end
  end

  def get_protocol_path(_), do: :error
end

defimpl Typespecable, for: Type.Protocol do
  def to_quote(%Type.Protocol{module: module}) do
    quote do
      unquote(module).t()
    end
  end

  def resolve_vars(type, _) do
    type
  end

  def get_protocol_path(_), do: :error
end

defimpl Typespecable, for: Type.GenericProtocol do
  def to_quote(%Type.GenericProtocol{module: module, generic: generic}) do
    quote do
      T.p(unquote(module), unquote(ExType.Typespecable.to_quote(generic)))
    end
  end

  def resolve_vars(%Type.GenericProtocol{generic: generic} = type, vars) do
    %{type | generic: Typespecable.resolve_vars(generic, vars)}
  end

  def get_protocol_path(_), do: :error
end

defimpl Typespecable, for: Type.Float do
  def to_quote(%Type.Float{}) do
    quote do
      float()
    end
  end

  def resolve_vars(type, _) do
    type
  end

  def get_protocol_path(_), do: {:ok, Float}
end

defimpl Typespecable, for: Type.Integer do
  def to_quote(%Type.Integer{}) do
    quote do
      integer()
    end
  end

  def resolve_vars(type, _) do
    type
  end

  def get_protocol_path(_), do: {:ok, Integer}
end

defimpl Typespecable, for: Type.Atom do
  def to_quote(%Type.Atom{literal: literal, value: value}) do
    if literal do
      value
    else
      quote do
        atom()
      end
    end
  end

  def resolve_vars(type, _) do
    type
  end

  def get_protocol_path(_), do: {:ok, Atom}
end

defimpl Typespecable, for: Type.AnyFunction do
  def to_quote(%Type.AnyFunction{}) do
    quote do
      ... -> any()
    end
  end

  def resolve_vars(type, _) do
    type
  end

  def get_protocol_path(_), do: {:ok, Function}
end

defimpl Typespecable, for: Type.RawFunction do
  def to_quote(%Type.RawFunction{args: args}) do
    quoted_anys = List.duplicate(quote(do: any()), length(args))

    quote do
      unquote_splicing(quoted_anys) -> any()
    end
  end

  def resolve_vars(type, _) do
    type
  end

  def get_protocol_path(_), do: {:ok, Function}
end

defimpl Typespecable, for: Type.TypedFunction do
  def to_quote(%Type.TypedFunction{inputs: inputs, output: output}) do
    quoted_inputs = Enum.map(inputs, &Typespecable.to_quote/1)
    quoted_output = Typespecable.to_quote(output)

    quote do
      unquote_splicing(quoted_inputs) -> unquote(quoted_output)
    end
  end

  def resolve_vars(%Type.TypedFunction{inputs: inputs, output: output}, vars) do
    %Type.TypedFunction{
      inputs: Enum.map(inputs, &Typespecable.resolve_vars(&1, vars)),
      output: Typespecable.resolve_vars(output, vars)
    }
  end

  def get_protocol_path(_), do: {:ok, Function}
end

defimpl Typespecable, for: Type.List do
  def to_quote(%Type.List{type: type}) do
    quote do
      [unquote(Typespecable.to_quote(type))]
    end
  end

  def resolve_vars(%Type.List{type: type}, vars) do
    %Type.List{type: Typespecable.resolve_vars(type, vars)}
  end

  def get_protocol_path(_), do: {:ok, List}
end

defimpl Typespecable, for: Type.Map do
  def to_quote(%Type.Map{key: key, value: value}) do
    quoted_key = Typespecable.to_quote(key)
    quoted_value = Typespecable.to_quote(value)

    quote do
      %{required(unquote(quoted_key)) => unquote(quoted_value)}
    end
  end

  def resolve_vars(%Type.Map{key: key, value: value}, vars) do
    %Type.Map{
      key: Typespecable.resolve_vars(key, vars),
      value: Typespecable.resolve_vars(value, vars)
    }
  end

  def get_protocol_path(_), do: {:ok, Map}
end

defimpl Typespecable, for: Type.TypedTuple do
  def to_quote(%Type.TypedTuple{types: types}) do
    quoted_types = Enum.map(types, &Typespecable.to_quote/1)

    quote do
      {unquote_splicing(quoted_types)}
    end
  end

  def resolve_vars(%Type.TypedTuple{types: types}, vars) do
    %Type.TypedTuple{types: Enum.map(types, &Typespecable.resolve_vars(&1, vars))}
  end

  def get_protocol_path(_), do: {:ok, Tuple}
end

defimpl Typespecable, for: Type.BitString do
  def to_quote(%Type.BitString{kind: kind}) do
    quote do
      unquote(kind)()
    end
  end

  def resolve_vars(type, _) do
    type
  end

  def get_protocol_path(_), do: {:ok, BitString}
end

defimpl Typespecable, for: Type.Struct do
  def to_quote(%Type.Struct{struct: struct, types: types}) do
    quote do
      %unquote(struct){
        unquote_splicing(
          Enum.map(types, fn {key, value} ->
            {key, Typespecable.to_quote(value)}
          end)
        )
      }
    end
  end

  def resolve_vars(type, _) do
    # TODO: fix this
    type
  end

  # TODO: fix this
  def get_protocol_path(_), do: :error
end
