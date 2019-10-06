defmodule ExType.Type do
  @moduledoc false

  alias ExType.Assert

  @type t ::
          ExType.Type.Any.t()
          | ExType.Type.None.t()
          | ExType.Type.Union.t()
          | ExType.Type.Intersection.t()
          | ExType.Type.Protocol.t()
          | ExType.Type.GenericProtocol.t()
          | ExType.Type.Float.t()
          | ExType.Type.Integer.t()
          | ExType.Type.Atom.t()
          | ExType.Type.Reference.t()
          | ExType.Type.AnyFunction.t()
          | ExType.Type.RawFunction.t()
          | ExType.Type.TypedFunction.t()
          | ExType.Type.Port.t()
          | ExType.Type.PID.t()
          | ExType.Type.AnyTuple.t()
          | ExType.Type.TypedTuple.t()
          | ExType.Type.SpecVariable.t()
          # Map.Empty
          | ExType.Type.Map.t()
          | ExType.Type.Struct.t()
          | ExType.Type.StructLikeMap.t()
          # List.Empty
          | ExType.Type.List.t()
          | ExType.Type.BitString.t()

  defmodule Any do
    @moduledoc false

    @type t :: %__MODULE__{}

    defstruct []
  end

  def any, do: %Any{}

  defmodule None do
    @moduledoc false

    @type t :: %__MODULE__{}

    defstruct []
  end

  def none, do: %None{}

  defmodule Union do
    @moduledoc false

    @type t :: %__MODULE__{
            types: [ExType.Type.t()]
          }

    defstruct [:types]
  end

  def union(types) when is_list(types) do
    Assert.is_list_of_type_structs!(types)

    %Union{types: types}
  end

  # assert_type_struct

  defmodule Intersection do
    @moduledoc false

    @type t :: %__MODULE__{
            types: [ExType.Type.t()]
          }

    defstruct [:types]
  end

  def intersection(types) when is_list(types) do
    Assert.is_list_of_type_structs!(types)
    %Intersection{types: types}
  end

  defmodule SpecVariable do
    @moduledoc false

    @type t :: %__MODULE__{
            name: atom(),
            type: ExType.Type.t(),
            spec: {atom(), atom(), pos_integer()},
            id: integer()
          }
    defstruct [:name, :type, :spec, :id]
  end

  defmodule Protocol do
    @moduledoc false

    @type t :: %__MODULE__{
            module: ExType.Type.Atom.t()
          }
    defstruct [:module]
  end

  defmodule GenericProtocol do
    @moduledoc false

    @type t :: %__MODULE__{
            module: atom(),
            generic: ExType.Type.t()
          }
    defstruct [:module, :generic]
  end

  def generic_protocol(module, generic) do
    Assert.is_type_struct!(generic)

    %GenericProtocol{module: module, generic: generic}
  end

  defmodule Float do
    @moduledoc false

    @type t :: %__MODULE__{}

    defstruct []
  end

  def float, do: %Float{}

  defmodule Integer do
    @moduledoc false

    @type t :: %__MODULE__{}

    defstruct []
  end

  def integer, do: %Integer{}

  defmodule Atom do
    @moduledoc false

    @type t :: %__MODULE__{
            literal: boolean(),
            value: atom()
          }

    defstruct [:literal, :value]
  end

  def atom, do: %Atom{}

  defmodule Reference do
    @moduledoc false

    @type t :: %__MODULE__{}

    defstruct []
  end

  def reference, do: %Reference{}

  defmodule AnyFunction do
    @moduledoc false

    @type t :: %__MODULE__{}

    defstruct []
  end

  def any_function, do: %AnyFunction{}

  defmodule RawFunction do
    @moduledoc false

    @type t :: %__MODULE__{
            arity: integer(),
            clauses: [{[any()], any(), any()}],
            context: ExType.Context.t()
          }

    defstruct [:arity, :clauses, :context]
  end

  defmodule TypedFunction do
    @moduledoc false

    @type t :: %__MODULE__{
            inputs: [ExType.Type.t()],
            output: ExType.Type.t()
          }
    defstruct [:inputs, :output]
  end

  defmodule List do
    @moduledoc false

    @type t :: %__MODULE__{
            type: ExType.Type.t()
          }

    defstruct [:type]
  end

  def list(type) do
    Assert.is_type_struct!(type)

    %List{type: type}
  end

  # StructLikeMap
  # Map.StructLike => it's map, not struct, but it has all atom as key,
  #                   so it's struct like map

  defmodule Map do
    @moduledoc false

    @type t :: %__MODULE__{
            key: ExType.Type.t(),
            value: ExType.Type.t()
          }

    defstruct [:key, :value]
  end

  def map(key_type, value_type) do
    Assert.is_type_struct!(key_type)
    Assert.is_type_struct!(value_type)

    %Map{key: key_type, value: value_type}
  end

  # Struct and TypedStruct ?
  defmodule Struct do
    @moduledoc false

    @type t :: %__MODULE__{
            struct: atom(),
            types: %{required(atom()) => ExType.Type.t()}
          }

    defstruct [:struct, :types]
  end

  defmodule StructLikeMap do
    @moduledoc false

    @type t :: %__MODULE__{
            types: %{required(atom()) => ExType.Type.t()}
          }

    defstruct [:types]
  end

  defmodule Port do
    @moduledoc false

    @type t :: %__MODULE__{}

    defstruct []
  end

  def port, do: %Port{}

  defmodule PID do
    @moduledoc false

    @type t :: %__MODULE__{}

    defstruct []
  end

  def pid, do: %PID{}

  defmodule AnyTuple do
    @moduledoc false

    @type t :: %__MODULE__{}

    defstruct []
  end

  def any_tuple, do: %AnyTuple{}

  defmodule TypedTuple do
    @moduledoc false

    @type t :: %__MODULE__{
            types: [ExType.Type.t()]
          }

    defstruct [:types]
  end

  def typed_tuple(types) when is_list(types) do
    Assert.is_list_of_type_structs!(types)

    %TypedTuple{types: types}
  end

  # TODO: distinguish bitstring and binary ???
  defmodule BitString do
    @moduledoc false

    @type t :: %__MODULE__{}

    defstruct []
  end

  def bit_string, do: %BitString{}
end
