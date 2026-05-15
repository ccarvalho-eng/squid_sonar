defmodule SquidSonarExample.Steps.RetryOnce do
  @moduledoc false

  use SquidMesh.Step,
    name: :retry_once,
    description: "Requests one retry before succeeding",
    input_schema: [
      order: [type: :map, required: true]
    ],
    output_schema: [
      order_id: [type: :string, required: true],
      status: [type: :string, required: true]
    ]

  @impl true
  def run(%{order: %{id: order_id}}, %SquidMesh.Step.Context{attempt: attempt}) do
    case attempt do
      1 ->
        {:retry, %{code: "retry_later", message: "Retry #{order_id} after a short delay"}}

      _next_attempt ->
        {:ok, %{order_id: order_id, status: "ok"}}
    end
  end
end
