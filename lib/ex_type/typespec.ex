defmodule ExType.Typespec do
  @moduledoc false

  alias ExType.{
    Type,
    Typespec,
    Typespecable,
    Helper,
    ArgumentExpander
  }

  require ExType.Helper

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
          {:@, _, [{:spec, _, [{:"::", _, [{name, _, args}, _]}]}]} ->
            {code, [{name, length(args)} | acc]}

          {:@, _, [{:spec, _, [{:when, _, [{:"::", _, [{name, _, args}, _]}, _]}]}]} ->
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
        @moduledoc false
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
        fetch_type(module, name, arity)
    end
  end

  def fetch_type(module, name, arity) do
    case Code.Typespec.fetch_types(module) do
      {:ok, raw_types} ->
        result =
          raw_types
          |> Enum.map(fn {kind, type} when kind in [:type, :typep, :opaque] ->
            Code.Typespec.type_to_quoted(type)
          end)
          |> Enum.find(fn
            {:"::", _, [{^name, _, args}, _]} when is_list(args) ->
              arity == length(args)

            _ ->
              false
          end)

        case result do
          nil ->
            {:error, {:not_found_type, module, name, arity}}

          {:"::", _, [left, right]} ->
            {:ok, left, right}
        end

      :error ->
        {:error, {:not_found_type, module}}
    end
  end

  # {args, result, vars}
  def from_beam_spec(module, name, arity) when is_atom(module) do
    overrided_module = String.to_atom("Elixir.ExType.Typespec.#{module}")

    case fetch_quoted_specs(overrided_module, name, arity) do
      {:ok, specs} ->
        {:ok, convert_specs(specs, name)}

      {:error, _} ->
        case fetch_quoted_specs(module, name, arity) do
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

  def fetch_quoted_specs(module, name, arity) do
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
            {:error, "cannot find beam spec for #{Macro.to_string(module)}.#{name}/#{arity}"}
        end

      :error ->
        {:error, "cannot find beam spec for #{Macro.to_string(module)}"}
    end
  end

  def convert_beam_spec(spec) do
    case spec do
      {:"::", _, [{name, _, args}, result]} ->
        {name, args, result, []}

      {:when, _, [{:"::", _, [{name, _, args}, result]}, vars]} ->
        {name, args, result, vars}
    end
  end

  # [x] | [y] => [x | y]
  def union_types(types) do
    types
    |> Enum.flat_map(fn
      %Type.Union{types: inner_types} ->
        inner_types

      other ->
        [other]
    end)
    |> Enum.group_by(fn
      %Type.List{} -> :list
      _ -> :others
    end)
    |> Enum.flat_map(fn
      # TODO: support other container types
      {:list, list} ->
        [
          %Type.List{
            type:
              list
              |> Enum.map(fn %Type.List{type: type} -> type end)
              |> union_types()
          }
        ]

      {:others, others} ->
        others
    end)
    |> Enum.uniq()
    |> case do
      [one] ->
        one

      multi ->
        if Enum.member?(multi, %Type.Any{}) do
          %Type.Any{}
        else
          %Type.Union{
            types:
              multi
              |> Enum.reject(fn x -> x == %Type.None{} end)
              |> Enum.sort()
          }
        end
    end
    |> case do
      %Type.Union{types: [one]} -> one
      other -> other
    end
  end

  def intersect_types(types) do
    types
    |> Enum.flat_map(fn
      %Type.Intersection{types: inner_types} ->
        inner_types

      other ->
        [other]
    end)
    |> Enum.uniq()
    |> case do
      [one] ->
        one

      multi ->
        if Enum.member?(multi, %Type.None{}) do
          %Type.None{}
        else
          %Type.Intersection{
            types:
              multi
              |> Enum.reject(fn x -> x == %Type.Any{} end)
              |> Enum.sort()
          }
        end
    end
  end

  # basic types: https://hexdocs.pm/elixir/typespecs.html#basic-types

  @spec eval_type(any(), {atom(), %{required(atom()) => Type.t()}}) :: Type.t()

  def eval_type({:any, _, []}, _) do
    %Type.Any{}
  end

  def eval_type({:none, _, []}, _) do
    %Type.None{}
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
    %Type.Float{}
  end

  def eval_type({:integer, _, []}, _) do
    %Type.Integer{}
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

  def eval_type({:<<>>, meta, _args}, _) do
    Helper.throw(
      message: "TODO: support binary type",
      meta: meta
    )
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
        %Type.Map{
          key: %Type.Any{},
          value: %Type.Any{}
        }

      [{{header, _, [key_type]}, value_type}] when header in [:required, :optional] ->
        %Type.Map{
          key: eval_type(key_type, context),
          value: eval_type(value_type, context)
        }

      _ ->
        if Enum.all?(args, fn {key, _} -> is_atom(key) end) do
          types =
            args
            |> Enum.map(fn {key, value} -> {key, eval_type(value, context)} end)
            |> Enum.into(%{})

          %Type.StructLikeMap{types: types}
        else
          {:error, "unsupported map type"}
        end
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

  def eval_type({first, second}, context) do
    eval_type({:{}, [], [first, second]}, context)
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

  # The `when x: var` pattern.
  # See https://hexdocs.pm/elixir/typespecs.html#defining-a-specification)
  # and https://github.com/gyson/ex_type/issues/25
  def eval_type({:var, meta, []}, context) do
    eval_type({:any, meta, []}, context)
  end

  def eval_type({:arity, meta, []}, context) do
    # TODO: support range
    eval_type({:integer, meta, []}, context)
  end

  # TODO: as_boolean

  def eval_type({:binary, _, []}, _) do
    %Type.BitString{}
  end

  def eval_type({:bitstring, _, []}, _) do
    %Type.BitString{}
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

  def eval_type({:nonempty_charlist, meta, []}, context) do
    eval_type({:nonempty_list, meta, [{:char, meta, []}]}, context)
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

  def eval_type({:iolist, meta, []}, context) do
    # TODO: fix this
    eval_type({:list, meta, []}, context)
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

  def eval_type({:list, _meta, [arg]}, context) do
    eval_type([arg], context)
  end

  def eval_type({:maybe_improper_list, meta, [_type1, _type2]}, context) do
    # TODO: fix this
    eval_type([{:any, meta, []}], context)
  end

  def eval_type({:nonempty_list, _, [arg]}, context) do
    # TODO: fix this
    eval_type([arg], context)
  end

  # TODO: maybe_improper_list
  # TODO: nonempty_maybe_improper_list
  # TODO: mfa

  def eval_type({:module, meta, []}, context) do
    eval_type({:atom, meta, []}, context)
  end

  def eval_type({:no_return, meta, []}, context) do
    eval_type({:none, meta, []}, context)
  end

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
  def eval_type({{:., meta, [T, :&]}, _, [tuple_type]}, context) do
    case eval_type(tuple_type, context) do
      %Type.TypedTuple{types: types} ->
        intersect_types(types)

      _ ->
        Helper.throw(
          message: "invalid intersection type",
          meta: meta
        )
    end
  end

  def eval_type({{:., _, [T, :p]}, _, [module, right]}, context) when is_atom(module) do
    %Type.GenericProtocol{
      module: module,
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

  def eval_type({:"::", _, [_, right]}, context) do
    eval_type(right, context)
  end

  # union type

  def eval_type({:|, _, [left, right]}, context) do
    union_types([
      eval_type(left, context),
      eval_type(right, context)
    ])
  end

  # integer range
  def eval_type({:.., _, [_left, _right]}, _context) do
    # TODO: support actual integer range
    %Type.Integer{}
  end

  # type variable
  def eval_type({name, meta, atom}, {_, vars} = context) when is_atom(name) and is_atom(atom) do
    case vars do
      %{^name => %Type.SpecVariable{} = type} ->
        type

      %{^name => raw} ->
        eval_type(raw, context)

      _ ->
        eval_type({name, meta, []}, context)
    end
  end

  # local type
  def eval_type({name, _meta, args} = type, {module, _} = context)
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

      {:error, message} ->
        Helper.inspect(%{
          error: :eval_type,
          type: type,
          context: context,
          message: message
        })

        Helper.throw(message: "Could not evaluate type")
    end
  end

  def eval_type({_, meta, _} = type, context) do
    Helper.inspect(%{
      error: :eval_type,
      type: type,
      context: context
    })

    Helper.throw(
      message: "cannot match eval_type",
      meta: meta
    )
  end

  def fetch_specs(module, name, arity) do
    case from_beam_spec(module, name, arity) do
      {:ok, specs} ->
        result =
          Enum.map(specs, fn {inputs, output, raw_vars} ->
            init_context = {module, Enum.into(raw_vars, %{})}

            spec_vars =
              raw_vars
              |> Enum.map(fn {var, expr} ->
                {var,
                 %Type.SpecVariable{
                   name: var,
                   type: eval_type(expr, init_context),
                   spec: {module, name, arity},
                   id: :erlang.unique_integer()
                 }}
              end)
              |> Enum.into(%{})

            new_context = {module, spec_vars}

            input_types = Enum.map(inputs, &eval_type(&1, new_context))
            output_type = eval_type(output, new_context)

            {input_types, output_type, spec_vars}
          end)

        {:ok, result}

      {:error, error} ->
        {:error, error}
    end
  end

  def eval_spec(module, name, input_types) do
    case fetch_specs(module, name, length(input_types)) do
      {:ok, specs} ->
        input_types
        |> ArgumentExpander.expand_union_types()
        |> Enum.reduce_while({:ok, Type.none()}, fn expanded_input_types, {:ok, acc_type} ->
          result_types =
            specs
            |> Enum.flat_map(fn {inputs, output, _} ->
              try do
                map =
                  Enum.zip(inputs, expanded_input_types)
                  |> Enum.reduce(%{}, fn {input, input_type}, acc_context ->
                    match_typespec(acc_context, input, input_type)
                  end)

                [Typespecable.resolve_vars(output, map)]
              catch
                error ->
                  # `unmatch` case could happen regularly.
                  if error.unmatch do
                    []
                  else
                    # this is actual type error, rethrow it
                    throw(error)
                  end
              end
            end)

          if Enum.empty?(result_types) do
            expr =
              quote do
                unquote(module).unquote(name)(
                  unquote_splicing(Enum.map(expanded_input_types, &Typespecable.to_quote/1))
                )
              end

            {:halt, {:error, Macro.to_string(expr)}}
          else
            {:cont, {:ok, union_types([acc_type | result_types])}}
          end
        end)

      {:error, _} ->
        {:error, :not_found}
    end
  end

  def match_typespec(map, type, type) do
    map
  end

  def match_typespec(map, %Type.Any{}, _) do
    map
  end

  def match_typespec(map, _, %Type.Any{}) do
    map
  end

  def match_typespec(map, %Type.SpecVariable{type: constraint} = sv, type) do
    case constraint do
      %Type.Any{} ->
        Map.put(map, sv, type)

      _ ->
        match_typespec(map, constraint, type)
    end
  end

  def match_typespec(
        map,
        %Type.TypedTuple{types: left_types},
        %Type.TypedTuple{types: right_types}
      )
      when length(left_types) == length(right_types) do
    Enum.zip(left_types, right_types)
    |> Enum.reduce(map, fn {left_type, right_type}, acc_map ->
      match_typespec(acc_map, left_type, right_type)
    end)
  end

  def match_typespec(map, %Type.Atom{literal: false}, %Type.Atom{}) do
    map
  end

  def match_typespec(
        map,
        %Type.TypedFunction{inputs: inputs, output: output},
        %Type.RawFunction{arity: arity, clauses: clauses, context: fn_context, meta: fn_meta}
      )
      when length(inputs) == arity do
    final_result_type =
      inputs
      # need to resolve inputs ? then, make sure it's concrete type ?
      |> Enum.map(&Typespecable.resolve_vars(&1, map))
      |> ArgumentExpander.expand_union_types()
      |> Enum.flat_map(fn input_types ->
        clauses
        |> Enum.flat_map(fn {args, guard, body} ->
          try do
            new_fn_context =
              Enum.zip(args, input_types)
              |> Enum.reduce(fn_context, fn {arg, input_type}, fn_context ->
                ExType.Unification.unify_pattern(fn_context, arg, input_type)
              end)
              |> ExType.Unification.unify_guard(guard)

            {:ok, new_fn_context}
          catch
            _ ->
              # cannot match spec
              :not_match
          end
          |> case do
            {:ok, new_fn_context} ->
              case body do
                [do: block] ->
                  {_context, type} = ExType.Checker.eval(new_fn_context, {:do, block})
                  [type]
                # For `do ... rescue ... end`-blocks, the result type can either be the first or the second part
                [do: block_try, rescue: block_rescue] ->
                  {_context, type_try} = ExType.Checker.eval(new_fn_context, {:do, block_try})
                  {_context, type_rescue} = ExType.Checker.eval(new_fn_context, {:rescue, block_rescue})
                  [Type.union([type_try, type_rescue])]
                block ->
                  {_context, type} = ExType.Checker.eval(new_fn_context, block)
                  [type]
              end

            :not_match ->
              []
          end
        end)
        |> case do
          [] ->
            # the input types does not match any pattern
            input_type_string =
              input_types
              |> Enum.map(fn t -> Typespecable.to_quote(t) |> Macro.to_string() end)
              |> Enum.join(", ")

            Helper.throw(
              message: "Cannot match input types (#{input_type_string})",
              context: fn_context,
              meta: fn_meta
            )

          types ->
            types
        end
      end)
      |> Typespec.union_types()

    match_typespec(map, output, final_result_type)
  end

  def match_typespec(map, %Type.Protocol{module: module}, type) do
    {:ok, name} = Typespecable.get_protocol_path(type)

    mod = Module.concat([module, name])

    case Code.ensure_compiled?(mod) do
      true ->
        map
    end
  end

  def match_typespec(
        map,
        %Type.GenericProtocol{module: module, generic: generic_typespec},
        %Type.GenericProtocol{module: module, generic: generic_type}
      )
      when is_atom(module) do
    match_typespec(map, generic_typespec, generic_type)
  end

  def match_typespec(map, %Type.GenericProtocol{module: module, generic: generic}, type) do
    {:ok, name} = Typespecable.get_protocol_path(type)

    mod = Module.concat([module, name])

    case eval_spec(mod, :ex_type_impl, [type]) do
      {:ok, output} ->
        match_typespec(map, generic, output)

      {:error, message} ->
        Helper.throw(message: message)
    end
  end

  def match_typespec(map, %Type.List{type: left_type}, %Type.List{type: right_type}) do
    match_typespec(map, left_type, right_type)
  end

  def match_typespec(
        map,
        %Type.Map{key: left_key_type, value: left_value_type},
        %Type.Map{key: right_key_type, value: right_value_type}
      ) do
    map
    |> match_typespec(left_key_type, right_key_type)
    |> match_typespec(left_value_type, right_value_type)
  end

  # when right type is union, we need to make sure all types matches
  def match_typespec(map, typespec, %Type.Union{types: union_types}) do
    Enum.reduce(union_types, map, fn type, acc_map ->
      match_typespec(acc_map, typespec, type)
    end)
  end

  def match_typespec(map, %Type.Union{types: union_types} = union, type) do
    union_types
    |> Enum.reduce({map, 0}, fn union_type, {acc_map, count} ->
      try do
        {match_typespec(map, union_type, type), count + 1}
      catch
        _ -> {acc_map, count}
      end
    end)
    |> case do
      {_, 0} ->
        type_string = type |> Typespecable.to_quote() |> Macro.to_string()
        union_string = union |> Typespecable.to_quote() |> Macro.to_string()
        Helper.throw(message: "type `#{type_string}` not match with union type `#{union_string}`")

      {map, _} ->
        map
    end
  end

  def match_typespec(map, %Type.AnyTuple{}, %Type.TypedTuple{}) do
    map
  end

  def match_typespec(_map, typespec, type) do
    typespec_string =
      typespec
      |> Typespecable.to_quote()
      |> Macro.to_string()

    type_string =
      type
      |> Typespecable.to_quote()
      |> Macro.to_string()

    Helper.throw(
      message: "unsupported match_typespec(map, #{typespec_string}, #{type_string})",
      unmatch: true
    )
  end
end
