defmodule ExType.Type do
  @moduledoc false

  @type t ::
          ExType.Type.Any.t()
          | ExType.Type.Union.t()
          | ExType.Type.Intersection.t()
          | ExType.Type.Number.t()
          | ExType.Type.Atom.t()
          | ExType.Type.Reference.t()
          | ExType.Type.Function.t()
          | ExType.Type.Port.t()
          | ExType.Type.Pid.t()
          | ExType.Type.Tuple.t()
          | ExType.Type.Map.t()
          | ExType.Type.Struct.t()
          | ExType.Type.List.t()
          | ExType.Type.BitString.t()

  defmodule Any do
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

  defmodule Function do
    @type t :: %__MODULE__{
            args: [ExType.Type.t()],
            body: any(),
            context: ExType.Context.t()
          }

    defstruct [:args, :body, :context]
  end

  defmodule List do
    @type t :: %__MODULE__{
            type: ExType.Type.t()
          }

    defstruct [:type]
  end

  defmodule Map do
    @type t :: %__MODULE__{
            key: ExType.Type.t(),
            value: ExType.Type.t()
          }

    defstruct [:key, :value]
  end

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

  defmodule Pid do
    @type t :: %__MODULE__{}

    defstruct []
  end

  defmodule Tuple do
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
