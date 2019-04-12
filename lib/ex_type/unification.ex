defmodule ExType.Unification.SpecError do
  defstruct [:spec, :type, :context, :line]
end

defmodule ExType.Unification.PatternError do
  defstruct [:pattern, :type, :context, :line]
end

defmodule ExType.Unification do
  @moduledoc false

  use ExType.Helper

  @spec unify_pattern(any(), Type.t(), Context.t()) :: {:ok, any(), Context.t()} | {:error, any()}

  def unify_pattern(integer, type, context) when is_integer(integer) do
    case type do
      %Type.Number{kind: :integer} ->
        {:ok, type, context}
    end
  end

  def unify_pattern(float, type, context) when is_float(float) do
    case type do
      %Type.Number{kind: :float} ->
        {:ok, type, context}
    end
  end

  def unify_pattern(binary, type, context) when is_binary(binary) do
    case type do
      %Type.BitString{} ->
        {:ok, type, context}
    end
  end

  def unify_pattern(atom, type, context) when is_atom(atom) do
    case type do
      %Type.Atom{literal: true, value: ^atom} ->
        {:ok, type, context}
    end
  end

  # {:ok, type, right}
  def unify_pattern({var, _, ctx}, type, context) when is_atom(var) and is_atom(ctx) do
    {:ok, type, Context.update_scope(context, var, type)}
  end

  # tuple
  def unify_pattern({first, second}, type, context) do
    unify_pattern({:{}, [], [first, second]}, type, context)
  end

  def unify_pattern({:{}, _, args}, type, context) do
    case type do
      %Type.Tuple{types: types} ->
        {unified_types, context} =
          Enum.zip(args, types)
          |> Enum.reduce({[], context}, fn {arg, t}, {acc, context} ->
            {:ok, type, context} = unify_pattern(arg, t, context)
            {acc ++ [type], context}
          end)

        {:ok, %Type.Tuple{types: unified_types}, context}

      %Type.Any{} ->
        {:error, :todo}

      _ ->
        {:error, :unify_pattern_tuple}
    end
  end

  # handle list
  def unify_pattern(list, type, context) when is_list(list) do
    case type do
      %Type.List{type: inner_type} ->
        case Enum.reverse(list) do
          [] ->
            {:ok, type, context}

          # if it's [a, b, c | d]
          [{:|, _, [left, right]} | items] ->
            new_context =
              [left | items]
              |> Enum.reverse()
              |> Enum.reduce(context, fn pattern, acc_context ->
                {:ok, _, new_acc} = unify_pattern(pattern, inner_type, acc_context)
                new_acc
              end)

            {:ok, _, new_context} = unify_pattern(right, type, new_context)

            {:ok, type, new_context}

          # [a, b, c] = [1, 2, 3]
          _ ->
            new_context =
              Enum.reduce(list, context, fn pattern, acc_context ->
                {:ok, _, new_acc} = unify_pattern(pattern, inner_type, acc_context)
                new_acc
              end)

            {:ok, type, new_context}
        end
    end
  end

  def unify_pattern(pattern, type, context) do
    Helper.pattern_error(pattern, type, context)
  end

  @spec unify_spec(any(), Type.t(), Context.t()) :: {:ok, any(), Context.t()} | {:error, any()}

  # Tuple

  def unify_spec({first, second}, type, context) do
    unify_spec({:{}, [], [first, second]}, type, context)
  end

  def unify_spec({:{}, _, args}, type, context) do
    case type do
      %Type.Tuple{types: types} when length(args) == length(types) ->
        result =
          Enum.zip(args, types)
          |> Enum.reduce_while({[], context}, fn {arg, type}, {acc, context} ->
            case unify_spec(arg, type, context) do
              {:ok, t, context} ->
                {:cont, {acc ++ [t], context}}

              {:error, error} ->
                {:halt, error}
            end
          end)

        case result do
          {unified_types, new_context} ->
            {:ok, %Type.Tuple{types: unified_types}, new_context}

          error ->
            {:error, error}
        end

      %Type.Any{} ->
        {types, context} =
          Enum.reduce(args, {[], context}, fn arg, {acc, context} ->
            {:ok, type, context} = unify_spec(arg, %Type.Any{}, context)
            {acc ++ [type], context}
          end)

        {:ok, %Type.Tuple{types: types}, context}
    end
  end

  def unify_spec(atom, type, context) when is_atom(atom) do
    case type do
      %Type.Atom{literal: true, value: ^atom} ->
        {:ok, type, context}

      %Type.Atom{literal: false} ->
        {:ok, %Type.Atom{literal: true, value: atom}, context}

      %Type.Any{} ->
        {:ok, %Type.Atom{literal: true, value: atom}, context}

      _ ->
        Helper.spec_error(atom, type, context)
    end
  end

  # function type

  def unify_spec([{:->, _, [inputs, output]}], type, context) do
    case type do
      %Type.Function{args: args, body: body, context: fn_context} ->
        {types, new_context} =
          Enum.reduce(inputs, {[], context}, fn input, {acc, ctx} ->
            {:ok, type, ctx} = unify_spec(input, %Type.Any{}, ctx)
            {acc ++ [type], ctx}
          end)

        new_fn_context =
          Enum.zip(args, types)
          |> Enum.reduce(fn_context, fn {arg, type}, fn_context ->
            {:ok, _, fn_context} = unify_pattern(arg, type, fn_context)
            fn_context
          end)

        {:ok, type, _} = ExType.Checker.eval(body, new_fn_context)

        {:ok, _, new_context} = unify_spec(output, type, new_context)

        {:ok, type, new_context}

      %Type.Any{} ->
        # TODO: handle it properly ?
        {:ok, type, context}
    end
  end

  def unify_spec([inner] = spec, type, context) do
    case type do
      %Type.List{type: inner_type} ->
        case unify_spec(inner, inner_type, context) do
          {:ok, inner_type, context} ->
            {:ok, %Type.List{type: inner_type}, context}

          {:error, _error} ->
            # TODO: link error
            Helper.spec_error(inner, inner_type, context)
        end

      %Type.Any{} ->
        case unify_spec(inner, %Type.Any{}, context) do
          {:ok, inner_type, context} ->
            {:ok, %Type.List{type: inner_type}, context}

          {:error, _error} ->
            Helper.spec_error(spec, type, context)
        end
    end
  end

  def unify_spec({:|, _, [left, right]}, type, context) do
    case unify_spec(left, type, context) do
      {:ok, t, c} ->
        {:ok, t, c}

      {:error, _} ->
        case unify_spec(right, type, context) do
          {:ok, t, c} ->
            {:ok, t, c}

          {:error, _} ->
            {:error, "not match union"}
        end
    end
  end

  def unify_spec({:integer, _, []}, type, context) do
    case type do
      %Type.Number{kind: :integer} ->
        {:ok, type, context}

      %Type.Number{kind: :number} ->
        # should cast number to integer ?
        {:ok, type, context}

      %Type.Any{} ->
        {:ok, %Type.Number{kind: :integer}, context}

      _ ->
        {:error, "not match integer"}
    end
  end

  def unify_spec({:float, _, []}, type, context) do
    case type do
      %Type.Number{kind: :float} ->
        {:ok, type, context}

      %Type.Number{kind: :number} ->
        # should cast number to float ?
        {:ok, type, context}

      %Type.Any{} ->
        {:ok, %Type.Number{kind: :float}, context}

      _ ->
        {:error, "not match float"}
    end
  end

  def unify_spec({:binary, _, []}, type, context) do
    case type do
      %Type.BitString{} ->
        {:ok, type, context}

      %Type.Any{} ->
        {:ok, %Type.BitString{kind: :binary}, context}
    end
  end

  def unify_spec({:any, _, []}, type, context) do
    {:ok, type, context}
  end

  # T.p(Enumerable.t(), x)
  def unify_spec({{:., _, [T, :p]}, _, args}, type, context) do
    case args do
      [{{:., _, [protocol, :t]}, _, []}, right] ->
        if Helper.is_protocol(protocol) do
          name =
            case type do
              %Type.Atom{} ->
                "Atom"

              %Type.Number{kind: :integer} ->
                "Integer"

              %Type.Number{kind: :float} ->
                "Float"

              %Type.Tuple{} ->
                "Tuple"

              %Type.List{} ->
                "List"

              %Type.Map{} ->
                "Map"
            end

          a = String.to_atom("Elixir.ExType.Typespec.#{protocol}.#{name}")

          case ExType.Typespec.from_beam_type(a, :t, 1) do
            {:ok, {{:., _, [T, :impl]}, _, [l, r]}} ->
              {:ok, _, new_context} = unify_spec(l, type, context)
              {:ok, tt, _} = unify_spec(r, %Type.Any{}, new_context)
              {:ok, _, context} = unify_spec(right, tt, context)
              {:ok, type, context}
          end
        else
          {:error, "#{protocol} is not protocol"}
        end
    end
  end

  # support remote type
  def unify_spec({{:., _, [module, name]}, _, []}, type, context)
      when is_atom(module) and is_atom(name) do
    {:ok, ts} = Code.Typespec.fetch_types(module)

    result =
      ts
      |> Enum.map(fn {:type, type} ->
        Code.Typespec.type_to_quoted(type)
      end)
      |> Enum.find(fn
        {:::, _, [{^name, _, []}, _]} ->
          true

        _ ->
          false
      end)

    case result do
      nil ->
        {:error, {:not_found_type, module, name}}

      {:::, _, [_, right]} ->
        unify_spec(right, type, context)
    end
  end

  def unify_spec({:%{}, _, [{{:required, _, [left]}, right}]}, type, context) do
    case type do
      %Type.Map{key: key, value: value} ->
        {:ok, _, context} = unify_spec(left, key, context)
        {:ok, _, context} = unify_spec(right, value, context)
        {:ok, type, context}
    end
  end

  # TODO: handle line with https://github.com/elixir-lang/elixir/pull/8918
  # type variable
  def unify_spec({name, _, ctx}, type, context)
      when is_atom(name) and (is_atom(ctx) or ctx == []) do
    unioned_type =
      case context.type_variables do
        %{^name => saved_type} ->
          ExType.Checker.union_types([type, saved_type])

        _ ->
          type
      end

    {:ok, unioned_type, Context.update_type_variables(context, name, unioned_type)}
  end

  def unify_spec(spec, type, context) do
    Helper.spec_error(spec, type, context)
  end
end
