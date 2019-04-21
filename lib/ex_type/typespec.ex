defmodule ExType.Typespec do
  @moduledoc false

  use ExType.Helper

  defmacro deftypespec(name, do: block) do
    module_name =
      case name do
        {:__aliases__, _, tokens} ->
          Module.concat([ExType.Typespec.Elixir | tokens])

        erlang_module when is_atom(erlang_module) ->
          Module.concat([ExType.Typespec, erlang_module])
      end

    # scan to find all specs
    defs =
      Macro.postwalk(block, [], fn code, acc ->
        case code do
          {:@, _, [{:spec, _, [{:::, _, [{name, _, args}, _]}]}]} ->
            {code, [{name, length(args)} | acc]}

          {:@, _, [{:spec, _, [{:when, _, [{:::, _, [{name, _, args}, _]}, _]}]}]} ->
            {code, [{name, length(args)} | acc]}

          _ ->
            {code, acc}
        end
      end)
      |> elem(1)
      # handle @spec unquote(:"====")(...) :: ...
      |> Enum.map(fn
        {{:unquote, _, [name]}, arity} -> {name, arity}
        {name, arity} -> {name, arity}
      end)
      |> Enum.uniq()
      |> Enum.map(fn {name, arity} ->
        quote do
          @dialyzer {:nowarn_function, {unquote(name), unquote(arity)}}
          def unquote(name)(unquote_splicing(List.duplicate(:_, arity))), do: nil
        end
      end)

    quote do
      defmodule unquote(module_name) do
        unquote(block)
        unquote_splicing(defs)
      end
    end
  end

  def from_beam_type(module, name, arity) do
    overrided_module = String.to_atom("Elixir.ExType.Typespec.#{module}")

    case fetch_type(overrided_module, name, arity) do
      {:ok, left, type} ->
        {:ok, left, type}

      {:error, _} ->
        case fetch_type(module, name, arity) do
          {:ok, left, type} ->
            {:ok, left, type}

          {:error, error} ->
            {:error, error}
        end
    end
  end

  def fetch_type(module, name, arity) do
    case Code.Typespec.fetch_types(module) do
      {:ok, ts} ->
        result =
          ts
          |> Enum.map(fn {kind, type} when kind in [:type, :typep] ->
            Code.Typespec.type_to_quoted(type)
          end)
          |> Enum.find(fn
            {:::, _, [{^name, _, args}, _]} when is_list(args) ->
              arity == length(args)

            _ ->
              false
          end)

        case result do
          nil ->
            {:error, {:not_found_type, module, name, arity}}

          {:::, _, [left, right]} ->
            {:ok, left, right}
        end

      :error ->
        {:error, {:not_found_type, module}}
    end
  end

  # {args, result, vars}
  def from_beam_spec(module, name, arity) when is_atom(module) do
    overrided_module = String.to_atom("Elixir.ExType.Typespec.#{module}")

    case fetch_specs(overrided_module, name, arity) do
      {:ok, specs} ->
        {:ok, convert_specs(specs, name)}

      {:error, _} ->
        case fetch_specs(module, name, arity) do
          {:ok, specs} ->
            {:ok, convert_specs(specs, name)}

          {:error, error} ->
            {:error, error}
        end
    end
  end

  defp convert_specs(specs, name) do
    Enum.map(specs, fn spec ->
      {^name, args, result, vars} = convert_beam_spec(spec)
      {args, result, vars}
    end)
  end

  def fetch_specs(module, name, arity) do
    case Code.Typespec.fetch_specs(module) do
      {:ok, specs} ->
        matched =
          Enum.filter(specs, fn x ->
            elem(x, 0) == {name, arity}
          end)

        case matched do
          [{{^name, ^arity}, erlang_abstract_formats}] ->
            result =
              erlang_abstract_formats
              |> Enum.map(fn eaf ->
                Code.Typespec.spec_to_quoted(name, eaf)
              end)

            {:ok, result}

          _ ->
            {:error, "cannot find beam spec for #{module}, #{name}, #{arity}"}
        end

      :error ->
        {:error, "cannot find beam spec for #{module}"}
    end
  end

  def convert_beam_spec(spec) do
    case spec do
      {:::, _, [{name, _, args}, result]} ->
        {name, args, result, []}

      {:when, _, [{:::, _, [{name, _, args}, result]}, vars]} ->
        {name, args, result, vars}
    end
  end

  def union_types(types) do
    types
    |> Enum.flat_map(fn
      %Type.Union{types: inner_types} ->
        inner_types

      other ->
        [other]
    end)
    |> Enum.uniq()
    |> case do
      [one] ->
        one

      multi ->
        if Enum.member?(multi, %Type.Any{}) do
          %Type.Any{}
        else
          %Type.Union{types: Enum.sort(multi)}
        end
    end
  end

  # TODO: T.&({any(), x}) => x
  # TODO: T.&({any(), x, y}) => T.&({x, y})
  def intersect_types(_types) do
    Helper.todo()
  end

  # basic types: https://hexdocs.pm/elixir/typespecs.html#basic-types

  @spec eval_type(any(), {atom(), %{required(atom()) => Type.t()}}) :: Type.t()

  def eval_type({:any, _, []}, _) do
    %Type.Any{}
  end

  def eval_type({:none, _, []}, _) do
    Helper.todo()
  end

  def eval_type({:atom, _, []}, _) do
    %Type.Atom{literal: false}
  end

  def eval_type({:map, _, []}, _) do
    %Type.Map{
      key: %Type.Any{},
      value: %Type.Any{}
    }
  end

  def eval_type({:pid, _, []}, _) do
    %Type.PID{}
  end

  def eval_type({:port, _, []}, _) do
    %Type.Port{}
  end

  def eval_type({:reference, _, []}, _) do
    %Type.Reference{}
  end

  def eval_type({:struct, _, []}, _) do
    %Type.Struct{}
  end

  def eval_type({:tuple, _, []}, _) do
    %Type.AnyTuple{}
  end

  def eval_type({:float, _, []}, _) do
    %Type.Number{kind: :float}
  end

  def eval_type({:integer, _, []}, _) do
    %Type.Number{kind: :integer}
  end

  def eval_type({:neg_integer, meta, []}, context) do
    # TODO: fix this
    eval_type({:integer, meta, []}, context)
  end

  def eval_type({:non_neg_integer, meta, []}, context) do
    # TODO: fix this
    eval_type({:integer, meta, []}, context)
  end

  def eval_type({:pos_integer, meta, []}, context) do
    # TODO: fix this
    eval_type({:integer, meta, []}, context)
  end

  # Literals

  def eval_type(atom, _) when is_atom(atom) do
    %Type.Atom{literal: true, value: atom}
  end

  def eval_type({:<<>>, _, _args}, _) do
    Helper.todo()
  end

  def eval_type([{:->, _, [inputs, output]}], context) when is_list(inputs) do
    case inputs do
      [{:..., _, _}] ->
        %Type.AnyFunction{}

      _ ->
        %Type.TypedFunction{
          inputs: Enum.map(inputs, &eval_type(&1, context)),
          output: eval_type(output, context)
        }
    end
  end

  def eval_type(integer, context) when is_integer(integer) do
    eval_type({:integer, [], []}, context)
  end

  def eval_type([type], context) do
    %Type.List{type: eval_type(type, context)}
  end

  # TODO: support other list types

  # map
  def eval_type({:%{}, _, args}, context) do
    case args do
      [] ->
        Helper.todo()

      [{{header, _, [key_type]}, value_type}] when header in [:required, :optional] ->
        %Type.Map{
          key: eval_type(key_type, context),
          value: eval_type(value_type, context)
        }
    end
  end

  # struct
  def eval_type({:%, _, [struct, {:%{}, _, args}]}, context) when is_atom(struct) do
    if Helper.is_struct(struct) do
      types =
        args
        |> Enum.map(fn {key, value} ->
          {key, eval_type(value, context)}
        end)
        |> Enum.into(%{})

      %Type.Struct{
        struct: struct,
        types: types
      }
    else
      raise ArgumentError, "#{struct} is not struct"
    end
  end

  def eval_type({:{}, _, args}, context) do
    %Type.TypedTuple{
      types: Enum.map(args, &eval_type(&1, context))
    }
  end

  # built-in types

  def eval_type({:term, meta, []}, context) do
    eval_type({:any, meta, []}, context)
  end

  def eval_type({:arity, meta, []}, context) do
    # TODO: support range
    eval_type({:integer, meta, []}, context)
  end

  # TODO: as_boolean

  def eval_type({:binary, _, []}, _) do
    %Type.BitString{kind: :binary}
  end

  def eval_type({:bitstring, _, []}, _) do
    %Type.BitString{kind: :bitstring}
  end

  def eval_type({:boolean, _, []}, context) do
    union_types([
      eval_type(true, context),
      eval_type(false, context)
    ])
  end

  def eval_type({:byte, meta, []}, context) do
    # TODO: use range
    eval_type({:integer, meta, []}, context)
  end

  def eval_type({:char, meta, []}, context) do
    # TODO: use range
    eval_type({:integer, meta, []}, context)
  end

  def eval_type({:charlist, meta, []}, context) do
    # TODO: use range
    eval_type([{:char, meta, []}], context)
  end

  def eval_type({:nonempty_charlist, _meta, []}, _context) do
    Helper.todo()
  end

  def eval_type({:fun, _, []}, _) do
    %Type.AnyFunction{}
  end

  def eval_type({:function, meta, []}, context) do
    eval_type({:fun, meta, []}, context)
  end

  def eval_type({:identifier, meta, []}, context) do
    union_types([
      eval_type({:pid, meta, []}, context),
      eval_type({:port, meta, []}, context),
      eval_type({:reference, meta, []}, context)
    ])
  end

  def eval_type({:iodata, meta, []}, context) do
    union_types([
      eval_type({:iolist, meta, []}, context),
      eval_type({:binary, meta, []}, context)
    ])
  end

  def eval_type({:iolist, _meta, []}, _context) do
    Helper.todo()
  end

  def eval_type({:keyword, meta, []}, context) do
    eval_type({:keyword, meta, [{:any, meta, []}]}, context)
  end

  def eval_type({:keyword, meta, [t]}, context) do
    eval_type([{:{}, meta, [{:atom, meta, []}, t]}], context)
  end

  def eval_type({:list, meta, []}, context) do
    eval_type([{:any, meta, []}], context)
  end

  def eval_type({:maybe_improper_list, meta, [_type1, _type2]}, context) do
    # TODO: fix this
    eval_type([{:any, meta, []}], context)
  end

  # TODO: nonempty_list
  # TODO: maybe_improper_list
  # TODO: nonempty_maybe_improper_list
  # TODO: mfa

  def eval_type({:module, meta, []}, context) do
    eval_type({:atom, meta, []}, context)
  end

  # TODO: no_return

  def eval_type({:node, meta, []}, context) do
    eval_type({:atom, meta, []}, context)
  end

  def eval_type({:number, meta, []}, context) do
    union_types([
      eval_type({:integer, meta, []}, context),
      eval_type({:float, meta, []}, context)
    ])
  end

  def eval_type({:timeout, meta, []}, context) do
    union_types([
      eval_type(:infinity, context),
      eval_type({:non_neg_integer, meta, []}, context)
    ])
  end

  # Remote types

  # T.&({type_1, type_2})
  def eval_type({{:., _, [T, :&]}, _, [tuple_type]}, context) do
    case eval_type(tuple_type, context) do
      %Type.TypedTuple{types: types} ->
        intersect_types(types)

      _ ->
        Helper.todo("error message")
    end
  end

  def eval_type({{:., _, [T, :p]}, _, [module, right]}, context) when is_atom(module) do
    %Type.GenericProtocol{
      module: module,
      generic: eval_type(right, context)
    }
  end

  def eval_type({{:., _, [T, :impl]}, _, [left, right]}, context) do
    %Type.ProtocolImpl{
      type: eval_type(left, context),
      generic: eval_type(right, context)
    }
  end

  def eval_type({{:., _, [module, name]}, _, args}, context)
      when is_atom(module) and is_atom(name) and is_list(args) do
    if Helper.is_protocol(module) and name == :t and args == [] do
      %Type.Protocol{module: module}
    else
      case from_beam_type(module, name, length(args)) do
        {:ok, {^name, _, type_args}, type_body} ->
          vars =
            args
            |> Enum.map(&eval_type(&1, context))
            |> Enum.zip(type_args)
            |> Enum.map(fn {type, {var, _, atom}} when is_atom(var) and is_atom(atom) ->
              {var, type}
            end)
            |> Enum.into(%{})

          eval_type(type_body, {module, vars})
      end
    end
  end

  def eval_type({:::, _, [_, right]}, context) do
    eval_type(right, context)
  end

  # union type

  def eval_type({:|, _, [left, right]}, context) do
    union_types([
      eval_type(left, context),
      eval_type(right, context)
    ])
  end

  # type variable
  def eval_type({name, meta, atom}, {_, vars} = context) when is_atom(name) and is_atom(atom) do
    case vars do
      %{^name => type} ->
        type

      _ ->
        eval_type({name, meta, []}, context)
    end
  end

  # local type
  def eval_type({name, _meta, args}, {module, _} = context)
      when is_atom(name) and is_list(args) do
    case from_beam_type(module, name, length(args)) do
      {:ok, {^name, _, type_args}, type_body} ->
        vars =
          args
          |> Enum.map(&eval_type(&1, context))
          |> Enum.zip(type_args)
          |> Enum.map(fn {type, {var, _, atom}} when is_atom(var) and is_atom(atom) ->
            {var, type}
          end)
          |> Enum.into(%{})

        eval_type(type_body, {module, vars})
    end
  end

  def eval_type(type, context) do
    raise Helper.inspect(%{
            error: :eval_type,
            type: type,
            context: context
          })

    Helper.todo("cannot match eval_type")
  end

  def get_spec(module, name, arity) do
    case from_beam_spec(module, name, arity) do
      {:ok, specs} ->
        result =
          Enum.map(specs, fn {inputs, output, raw_vars} ->
            empty_context = {module, %{}}

            spec_vars =
              raw_vars
              |> Enum.map(fn {var, expr} ->
                {var,
                 %Type.SpecVariable{
                   name: var,
                   type: eval_type(expr, empty_context),
                   spec: {module, name, arity},
                   id: :erlang.unique_integer()
                 }}
              end)
              |> Enum.into(%{})

            new_context = {module, spec_vars}

            input_types = Enum.map(inputs, &eval_type(&1, new_context))
            output_type = eval_type(output, new_context)

            {input_types, output_type, Map.values(spec_vars)}
          end)

        {:ok, result}

      {:error, error} ->
        {:error, error}
    end
  end

  def eval_spec(module, name, input_types) do
    case get_spec(module, name, length(input_types)) do
      {:ok, specs} ->
        result_types =
          specs
          |> Enum.flat_map(fn {inputs, output, _} ->
            case match_typespec_list(inputs, input_types, %{}, fn x -> x end) do
              {:ok, _, new_map} ->
                [Typespec.resolve_typespec(output, new_map)]

              {:error, _} ->
                []
            end
          end)

        if Enum.empty?(result_types) do
          {:error, "not match any"}
        else
          {:ok, union_types(result_types)}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  def match_typespec(type, type, context) do
    {:ok, type, context}
  end

  def match_typespec(%Type.Any{}, _, context) do
    {:ok, %Type.Any{}, context}
  end

  def match_typespec(typespec, %Type.Any{}, context) do
    {:ok, typespec, context}
  end

  def match_typespec(%Type.SpecVariable{type: constraint} = sv, type, context) do
    case constraint do
      %Type.Any{} ->
        {:ok, type, Map.put(context, sv, type)}
    end
  end

  def match_typespec(
        %Type.TypedTuple{types: left_types},
        %Type.TypedTuple{types: right_types},
        context
      ) do
    match_typespec_list(left_types, right_types, context, fn types ->
      %Type.TypedTuple{types: types}
    end)
  end

  def match_typespec(%Type.Atom{literal: false} = spec, %Type.Atom{}, context) do
    {:ok, spec, context}
  end

  def match_typespec(
        %Type.TypedFunction{inputs: inputs, output: output},
        %Type.RawFunction{args: args, body: body, context: fn_context},
        context
      )
      when length(inputs) == length(args) do
    # need to resolve inputs ? then, make sure it's concrete type ?
    resolved_inputs = Enum.map(inputs, &resolve_typespec(&1, context))

    new_fn_context =
      Enum.zip(args, resolved_inputs)
      |> Enum.reduce(fn_context, fn {arg, resolved_input}, fn_context ->
        {:ok, _, fn_context} = ExType.Unification.unify_pattern(arg, resolved_input, fn_context)
        fn_context
      end)

    # TODO: type guards

    {:ok, result_type, _} = ExType.Checker.eval(body, new_fn_context)

    case match_typespec(output, result_type, context) do
      {:ok, _, new_context} ->
        {:ok, %Type.TypedFunction{inputs: resolved_inputs, output: result_type}, new_context}

      {:error, error} ->
        {:error, error}
    end
  end

  def match_typespec(%Type.Protocol{module: module}, type, context) do
    # TODO: more cases...
    name =
      case type do
        %Type.BitString{} ->
          BitString
      end

    mod = Module.concat([module, name])

    case Code.ensure_compiled?(mod) do
      true ->
        {:ok, type, context}
    end
  end

  def match_typespec(%Type.GenericProtocol{module: module, generic: generic}, type, context) do
    name =
      case type do
        %Type.Atom{} ->
          Atom

        %Type.Number{kind: :integer} ->
          Integer

        %Type.Number{kind: :float} ->
          Float

        %Type.TypedTuple{} ->
          Tuple

        %Type.List{} ->
          List

        %Type.Map{} ->
          Map
      end

    mod = Module.concat([module, name])

    case eval_spec(mod, :ex_type_impl, [type]) do
      {:ok, output} ->
        # Helper.inspect {generic, output}
        match_typespec(generic, output, context)
    end
  end

  def match_typespec(%Type.List{type: left_type}, %Type.List{type: right_type}, context) do
    case match_typespec(left_type, right_type, context) do
      {:ok, result_type, context} ->
        {:ok, %Type.List{type: result_type}, context}

      {:error, error} ->
        {:error, error}
    end
  end

  def match_typespec(
        %Type.Map{key: left_key_type, value: left_value_type},
        %Type.Map{key: right_key_type, value: right_value_type},
        context
      ) do
    match_typespec_list(
      [left_key_type, left_value_type],
      [right_key_type, right_value_type],
      context,
      fn [key, value] ->
        %Type.Map{key: key, value: value}
      end
    )
  end

  def match_typespec(%Type.Union{types: union_types}, type, context) do
    # match spec with each type of it
    Enum.reduce_while(union_types, {:error, "not match with union"}, fn union_type, acc ->
      case match_typespec(union_type, type, context) do
        {:ok, _, _} ->
          {:halt, {:ok, type, context}}

        {:error, _} ->
          {:cont, acc}
      end
    end)
  end

  def match_typespec(typespec, type, context) do
    Helper.inspect({:error, {"not match_typespec", typespec, type, context}})
  end

  def match_typespec_list(left_types, right_types, context, wrap)
      when length(left_types) == length(right_types) do
    Enum.zip(left_types, right_types)
    |> Enum.reduce_while({:ok, [], context}, fn {left_type, right_type},
                                                {:ok, reversed_types, acc_context} ->
      case match_typespec(left_type, right_type, acc_context) do
        {:ok, result_type, acc_context} ->
          {:cont, {:ok, [result_type | reversed_types], acc_context}}

        {:error, error} ->
          {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, reversed_types, context} ->
        {:ok, wrap.(Enum.reverse(reversed_types)), context}

      other ->
        other
    end
  end

  def match_typespec_list(_left_types, _right_types, _context, _) do
    Helper.todo("length not match")
  end

  def resolve_typespec(%Type.SpecVariable{} = sv, map) do
    Map.fetch!(map, sv)
  end

  def resolve_typespec(%Type.List{type: type}, map) do
    %Type.List{type: resolve_typespec(type, map)}
  end

  def resolve_typespec(%Type.TypedTuple{types: types}, map) do
    %Type.TypedTuple{types: Enum.map(types, &resolve_typespec(&1, map))}
  end

  def resolve_typespec(%Type.Union{types: types}, map) do
    union_types(Enum.map(types, &resolve_typespec(&1, map)))
  end

  def resolve_typespec(%Type.Intersection{types: types}, map) do
    intersect_types(Enum.map(types, &resolve_typespec(&1, map)))
  end

  def resolve_typespec(%Type.GenericProtocol{generic: generic} = t, map) do
    %{t | generic: resolve_typespec(generic, map)}
  end

  # typed_function need it ?
  def resolve_typespec(%Type.TypedFunction{inputs: inputs, output: output}, map) do
    %Type.TypedFunction{
      inputs: Enum.map(inputs, &resolve_typespec(&1, map)),
      output: resolve_typespec(output, map)
    }
  end

  # ... more ...

  def resolve_typespec(type, _) do
    type
  end
end
