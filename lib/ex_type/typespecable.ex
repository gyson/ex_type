# Protocol to convert ExType.Type to quoted typespec

defprotocol ExType.Typespecable do
  def to_quote(x)
end

alias ExType.Type
alias ExType.Typespecable

defimpl Typespecable, for: Type.Any do
  def to_quote(_) do
    quote do
      any()
    end
  end
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
end

defimpl Typespecable, for: Type.Intersection do
  def to_quote(%Type.Intersection{types: types}) do
    quote do
      T.&({unquote_splicing(Enum.map(types, &ExType.Typespecable.to_quote/1))})
    end
  end
end

defimpl Typespecable, for: Type.Protocol do
  def to_quote(%Type.Protocol{module: module}) do
    quote do
      unquote(module).t()
    end
  end
end

defimpl Typespecable, for: Type.GenericProtocol do
  def to_quote(%Type.GenericProtocol{protocol: protocol, generic: generic}) do
    quote do
      T.p(unquote(protocol.module).t(), unquote(ExType.Typespecable.to_quote(generic)))
    end
  end
end

defimpl Typespecable, for: Type.Number do
  def to_quote(%Type.Number{kind: kind}) do
    quote do
      unquote(kind)()
    end
  end
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
end

defimpl Typespecable, for: Type.AnyFunction do
  def to_quote(%Type.AnyFunction{}) do
    quote do
      ... -> any()
    end
  end
end

defimpl Typespecable, for: Type.AnonymousFunction do
  def to_quote(%Type.AnonymousFunction{args: args}) do
    quoted_anys = List.duplicate(quote(do: any()), length(args))

    quote do
      unquote_splicing(quoted_anys) -> any()
    end
  end
end

defimpl Typespecable, for: Type.TypedFunction do
  def to_quote(%Type.TypedFunction{inputs: inputs, output: output}) do
    quoted_inputs = Enum.map(inputs, &Typespecable.to_quote/1)
    quoted_output = Typespecable.to_quote(output)

    quote do
      unquote_splicing(quoted_inputs) -> unquote(quoted_output)
    end
  end
end

defimpl Typespecable, for: Type.List do
  def to_quote(%Type.List{type: type}) do
    quote do
      [unquote(Typespecable.to_quote(type))]
    end
  end
end

defimpl Typespecable, for: Type.Map do
  def to_quote(%Type.Map{key: key, value: value}) do
    quoted_key = Typespecable.to_quote(key)
    quoted_value = Typespecable.to_quote(value)

    quote do
      %{required(unquote(quoted_key)) => unquote(quoted_value)}
    end
  end
end

defimpl Typespecable, for: Type.Tuple do
  def to_quote(%Type.Tuple{types: types}) do
    quoted_types = Enum.map(types, &Typespecable.to_quote/1)

    quote do
      {unquote_splicing(quoted_types)}
    end
  end
end

defimpl Typespecable, for: Type.BitString do
  def to_quote(%Type.BitString{kind: kind}) do
    quote do
      unquote(kind)()
    end
  end
end
