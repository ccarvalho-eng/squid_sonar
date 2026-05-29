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
  @callback cancel(term(), keyword()) ::
              {:ok, SquidMesh.ReadModel.Inspection.Snapshot.t()} | {:error, term()}
  @callback resume(term(), map(), keyword()) ::
              {:ok, SquidMesh.ReadModel.Inspection.Snapshot.t()} | {:error, term()}
  @callback approve(term(), map(), keyword()) ::
              {:ok, SquidMesh.ReadModel.Inspection.Snapshot.t()} | {:error, term()}
  @callback reject(term(), map(), keyword()) ::
              {:ok, SquidMesh.ReadModel.Inspection.Snapshot.t()} | {:error, term()}
  @callback replay(term(), keyword()) ::
              {:ok, SquidMesh.ReadModel.Inspection.Snapshot.t()} | {:error, term()}

  @behaviour __MODULE__

  @impl true
  def list_runs(filters, opts), do: SquidMesh.list_runs(filters, opts)

  @impl true
  def inspect_run(run_id, opts), do: SquidMesh.inspect_run(run_id, opts)

  @impl true
  def inspect_run_graph(run_id, opts), do: SquidMesh.inspect_run_graph(run_id, opts)

  @impl true
  def explain_run(run_id, opts), do: SquidMesh.explain_run(run_id, opts)

  @impl true
  def cancel(run_id, opts), do: SquidMesh.cancel(run_id, opts)

  @impl true
  def resume(run_id, attrs, opts), do: SquidMesh.resume(run_id, attrs, opts)

  @impl true
  def approve(run_id, attrs, opts), do: SquidMesh.approve(run_id, attrs, opts)

  @impl true
  def reject(run_id, attrs, opts), do: SquidMesh.reject(run_id, attrs, opts)

  @impl true
  def replay(run_id, opts), do: SquidMesh.replay(run_id, opts)
end
