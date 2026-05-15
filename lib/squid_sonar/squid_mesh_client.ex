defmodule SquidSonar.SquidMeshClient do
  @moduledoc """
  Client boundary for Squid Mesh public APIs.
  """

  @callback list_runs(keyword(), keyword()) :: {:ok, [SquidMesh.Run.t()]} | {:error, term()}
  @callback inspect_run(term(), keyword()) :: {:ok, SquidMesh.Run.t()} | {:error, term()}
  @callback explain_run(term(), keyword()) ::
              {:ok, SquidMesh.RunExplanation.t()} | {:error, term()}

  @behaviour __MODULE__

  @impl true
  def list_runs(filters, opts), do: SquidMesh.list_runs(filters, opts)

  @impl true
  def inspect_run(run_id, opts), do: SquidMesh.inspect_run(run_id, opts)

  @impl true
  def explain_run(run_id, opts), do: SquidMesh.explain_run(run_id, opts)
end
