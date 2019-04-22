defmodule ExType.Type do
  @moduledoc false

  @type t ::
          ExType.Type.Any.t()
          | ExType.Type.None.t()
          | ExType.Type.Union.t()
          | ExType.Type.Intersection.t()
          | ExType.Type.Protocol.t()
          | ExType.Type.GenericProtocol.t()
          | ExType.Type.Number.t()
          | ExType.Type.Atom.t()
          | ExType.Type.Reference.t()
          | ExType.Type.Function.t()
          | ExType.Type.AnyFunction.t()
          | ExType.Type.RawFunction.t()
          | ExType.Type.TypedFunction.t()
          | ExType.Type.Port.t()
          | ExType.Type.PID.t()
          | ExType.Type.AnyTuple.t()
          | ExType.Type.TypedTuple.t()

          # Map.Empty
          | ExType.Type.Map.t()
          | ExType.Type.Struct.t()
          # List.Empty
          | ExType.Type.List.t()
          | ExType.Type.BitString.t()

  defmodule Any do
    @type t :: %__MODULE__{}

    defstruct []
  end

  defmodule None do
    @type t :: %__MODULE__{}

    defstruct []
  end

  defmodule Union do
    @type t :: %__MODULE__{
            types: [ExType.Type.t()]
          }

    defstruct [:types]
  end

  defmodule Intersection do
    @type t :: %__MODULE__{
            types: [ExType.Type.t()]
          }

    defstruct [:types]
  end

  defmodule SpecVariable do
    @type t :: %__MODULE__{
            name: atom(),
            type: Type.t(),
            spec: {atom(), atom(), pos_integer()},
            id: integer()
          }
    defstruct [:name, :type, :spec, :id]
  end

  defmodule Protocol do
    @type t :: %__MODULE__{
            module: ExType.Type.Atom.t()
          }
    defstruct [:module]
  end

  defmodule GenericProtocol do
    @type t :: %__MODULE__{
            module: atom(),
            generic: ExType.Type.t()
          }
    defstruct [:module, :generic]
  end

  defmodule Number do
    @type t :: %__MODULE__{
            kind:
              :integer
              | :float
              | :number
              | :pos_integer
              | :neg_integer
              | :non_pos_integer
              | :non_neg_integer
          }

    defstruct [:kind]
  end

  defmodule Atom do
    @type t :: %__MODULE__{
            literal: boolean(),
            value: atom()
          }

    defstruct [:literal, :value]
  end

  defmodule Reference do
    @type t :: %__MODULE__{}

    defstruct []
  end

  defmodule AnyFunction do
    @type t :: %__MODULE__{}

    defstruct []
  end

  defmodule RawFunction do
    @type t :: %__MODULE__{
            args: [any()],
            body: any(),
            context: ExType.Context.t()
          }

    defstruct [:args, :body, :context]
  end

  defmodule TypedFunction do
    @type t :: %__MODULE__{
            inputs: [ExType.Type.t()],
            output: ExType.Type.t()
          }
    defstruct [:inputs, :output]
  end

  defmodule List do
    @type t :: %__MODULE__{
            type: ExType.Type.t()
          }

    defstruct [:type]
  end

  # StructLikeMap
  # Map.StructLike => it's map, not struct, but it has all atom as key,
  #                   so it's struct like map

  defmodule Map do
    @type t :: %__MODULE__{
            key: ExType.Type.t(),
            value: ExType.Type.t()
          }

    defstruct [:key, :value]
  end

  # Struct and TypedStruct ?
  defmodule Struct do
    @type t :: %__MODULE__{
            struct: atom(),
            types: %{required(atom()) => ExType.Type.t()}
          }

    defstruct [:struct, :types]
  end

  defmodule Port do
    @type t :: %__MODULE__{}

    defstruct []
  end

  defmodule PID do
    @type t :: %__MODULE__{}

    defstruct []
  end

  defmodule AnyTuple do
    @type t :: %__MODULE__{}

    defstruct []
  end

  defmodule TypedTuple do
    @type t :: %__MODULE__{
            types: [ExType.Type.t()]
          }

    defstruct [:types]
  end

  defmodule BitString do
    @type t :: %__MODULE__{
            kind: :binary | :bitstring
          }

    defstruct [:kind]
  end
end
