defmodule ExType.Type do
  @moduledoc false

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

  defmodule None do
    @moduledoc false

    @type t :: %__MODULE__{}

    defstruct []
  end

  defmodule Union do
    @moduledoc false

    @type t :: %__MODULE__{
            types: [ExType.Type.t()]
          }

    defstruct [:types]
  end

  defmodule Intersection do
    @moduledoc false

    @type t :: %__MODULE__{
            types: [ExType.Type.t()]
          }

    defstruct [:types]
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

  defmodule Float do
    @moduledoc false

    @type t :: %__MODULE__{}

    defstruct []
  end

  defmodule Integer do
    @moduledoc false

    @type t :: %__MODULE__{}

    defstruct []
  end

  defmodule Atom do
    @moduledoc false

    @type t :: %__MODULE__{
            literal: boolean(),
            value: atom()
          }

    defstruct [:literal, :value]
  end

  defmodule Reference do
    @moduledoc false

    @type t :: %__MODULE__{}

    defstruct []
  end

  defmodule AnyFunction do
    @moduledoc false

    @type t :: %__MODULE__{}

    defstruct []
  end

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

  defmodule PID do
    @moduledoc false

    @type t :: %__MODULE__{}

    defstruct []
  end

  defmodule AnyTuple do
    @moduledoc false

    @type t :: %__MODULE__{}

    defstruct []
  end

  defmodule TypedTuple do
    @moduledoc false

    @type t :: %__MODULE__{
            types: [ExType.Type.t()]
          }

    defstruct [:types]
  end

  # TODO: distinguish bitstring and binary ???
  defmodule BitString do
    @moduledoc false

    @type t :: %__MODULE__{}

    defstruct []
  end
end
