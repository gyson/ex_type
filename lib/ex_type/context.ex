defmodule ExType.Context do
  @moduledoc false

  @type t :: %__MODULE__{
          env: any(),
          scope: any(),
          type_variables: any(),
          functions: map(),
          stacks: [any()]
        }

  defstruct env: nil,
            scope: %{},
            type_variables: %{},
            functions: %{},
            stacks: []

  def update_scope(%__MODULE__{scope: scope} = context, name, type) do
    %{context | scope: Map.put(scope, name, type)}
  end

  def update_type_variables(%__MODULE__{type_variables: type_variables} = context, name, type) do
    %{context | type_variables: Map.put(type_variables, name, type)}
  end
end

defimpl Inspect, for: ExType.Context do
  @moduledoc false

  def inspect(_env, _opts) do
    "%ExType.Context{}"
  end
end
