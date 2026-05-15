defmodule SquidSonarExample.Steps.FailPayment do
  @moduledoc false

  use SquidMesh.Step,
    name: :fail_payment,
    description: "Fails payment capture for a monitorable failed run",
    input_schema: [
      order: [type: :map, required: true]
    ]

  @impl true
  def run(%{order: %{id: order_id}}, _context) do
    {:error,
     %{
       code: "gateway_unavailable",
       message: "Payment gateway unavailable for #{order_id}",
       retryable?: false
     }}
  end
end
