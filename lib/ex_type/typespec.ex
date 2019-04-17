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
      {:ok, type} ->
        {:ok, type}

      {:error, _} ->
        case fetch_type(module, name, arity) do
          {:ok, type} ->
            {:ok, type}

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
          |> Enum.map(fn {:type, type} ->
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

          {:::, _, [_, right]} ->
            {:ok, right}
        end

      :error ->
        {:error, {:not_found_type, module}}
    end
  end

  # {args, result, vars}
  def from_beam_spec(module, name, arity) when is_atom(module) do
    # {module, name, arity} = Map.get(mapping(), {module, name, arity}, {module, name, arity})

    overrided_module = String.to_atom("Elixir.ExType.Typespec.#{module}")

    case fetch_specs(overrided_module, name, arity) do
      {:ok, specs} ->
        specs

      {:error, _} ->
        case fetch_specs(module, name, arity) do
          {:ok, specs} ->
            specs

          {:error, error} ->
            raise error
        end
    end
    |> Enum.map(fn spec ->
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

  # basic types: https://hexdocs.pm/elixir/typespecs.html#basic-types

  @spec eval_type(any(), Context.t()) :: Type.t()

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
    %Type.Tuple{}
  end

  def eval_type({:float, _, []}, _) do
    %Type.Number{kind: :float}
  end

  def eval_type({:integer, _, []}, _) do
    %Type.Number{kind: :integer}
  end

  def eval_type({:neg_integer, _, []}, _) do
    # TODO: fix this
    %Type.Number{kind: :integer}
  end

  def eval_type({:non_neg_integer, _, []}, _) do
    # TODO: fix this
    %Type.Number{kind: :integer}
  end

  def eval_type({:pos_integer, _, []}, _) do
    # TODO: fix this
    %Type.Number{kind: :integer}
  end

  # Literals

  def eval_type(atom, _) when is_atom(atom) do
    %Type.Atom{literal: true, value: atom}
  end

  def eval_type({:<<>>, _, _args}, _) do
    Helper.todo()
  end

  def eval_type({:->, _, [inputs, output]}, context) when is_list(inputs) do
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

  def eval_type(integer, _) when is_integer(integer) do
    # TODO: maybe support integer literal ?
    %Type.Number{kind: :integer}
  end

  def eval_type([type], context) do
    %Type.List{type: eval_type(type, context)}
  end

  # TODO: support other list types

  # map
  def eval_type({%{}, _, args}, context) do
    case args do
      [] ->
        raise ArgumentError, "TODO: support empty map spec"

      [{{:required, _, [key_type]}, value_type}] ->
        %Type.Map{
          key: eval_type(key_type, context),
          value: eval_type(value_type, context)
        }
    end
  end

  # struct
  def eval_type({:%, _, [_module, {%{}, _, _args}]}, _context) do
    Helper.todo()
  end

  def eval_type({:{}, _, args}, context) do
    %Type.Tuple{
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
    eval_type(
      [
        {:{}, meta,
         [
           eval_type({:atom, meta, []}, context),
           eval_type(t, context)
         ]}
      ],
      context
    )
  end

  def eval_type({:list, meta, []}, context) do
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

  # TODO: struct

  def eval_type({:timeout, meta, []}, context) do
    union_types([
      eval_type(:infinity, context),
      eval_type({:non_neg_integer, meta, []}, context)
    ])
  end

  # Remote types

  # T.&({type_1, type_2})
  def eval_type({{:., _, [T, :&]}, _, [{:{}, _, types}]}, context) do
    intersect_types(Enum.map(types, &eval_type(&1, context)))
  end

  def eval_type({{:., _, [T, :p]}, _, [left, right]}, context) do
    case eval_type(left, context) do
      %Type.Protocol{} = protocol ->
        %Type.GenericProtocol{
          protocol: protocol,
          generic: eval_type(right, context)
        }

      _ ->
        Helper.todo()
    end
  end

  def eval_type({{:., _, [T, :impl]}, _, [left, right]}, context) do
    %Type.ProtocolImpl{
      type: eval_type(left, context),
      generic: eval_type(right, context)
    }
  end

  def eval_type({{:., _, [module, name]}, _, args}, _context) do
    if Helper.is_protocol(module) and name == :t and args == [] do
      %Type.Protocol{module: module}
    else
      # it's remote type
      Helper.todo()
    end
  end

  # type variable
  def eval_type({name, _, ctx}, _context) when is_atom(name) and is_atom(ctx) do
    %Type.TypeVariable{name: name}
  end

  # union type

  def eval_type({:|, _, [left, right]}, context) do
    union_types([
      eval_type(left, context),
      eval_type(right, context)
    ])
  end

  def eval_type(type, context) do
    Helper.inspect(%{
      error: :eval_type,
      type: type,
      context: context
    })

    Helper.todo("cannot match eval_type")
  end

  # TODO: any() | x should be any()
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
        # sort for easy quick comparison
        sorted = Enum.sort(multi)
        %Type.Union{types: sorted}
    end
  end

  # TODO: T.&({any(), x}) => x
  # TODO: T.&({any(), x, y}) => T.&({x, y})
  def intersect_types(_types) do
    Helper.todo()
  end
end
