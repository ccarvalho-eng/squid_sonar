defmodule SquidSonar.SquidMeshClient do
  @moduledoc """
  Client boundary for Squid Mesh public APIs.
  """

  @callback list_runs(keyword(), keyword()) ::
              {:ok, [SquidMesh.ReadModel.Listing.Summary.t()]} | {:error, term()}
  @callback inspect_run(term(), keyword()) ::
              {:ok, SquidMesh.ReadModel.Inspection.Snapshot.t()} | {:error, term()}
  @callback inspect_run_graph(term(), keyword()) ::
              {:ok, SquidMesh.Runs.GraphInspection.t()} | {:error, term()}
  @callback explain_run(term(), keyword()) ::
              {:ok, SquidMesh.ReadModel.Explanation.Diagnostic.t()} | {:error, term()}

  @behaviour __MODULE__

  @impl true
  def list_runs(filters, opts), do: SquidMesh.list_runs(filters, opts)

  @impl true
  def inspect_run(run_id, opts), do: SquidMesh.inspect_run(run_id, opts)

  @impl true
  def inspect_run_graph(run_id, opts), do: SquidMesh.inspect_run_graph(run_id, opts)

  @impl true
  def explain_run(run_id, opts), do: SquidMesh.explain_run(run_id, opts)
end
