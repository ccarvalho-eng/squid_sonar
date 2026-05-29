defmodule SquidSonar.FakeSquidMeshClient do
  @moduledoc false

  @behaviour SquidSonar.SquidMeshClient

  @impl true
  def list_runs(_filters, _opts) do
    Process.get({__MODULE__, :list_runs}, {:ok, []})
  end

  @impl true
  def inspect_run(_run_id, _opts) do
    Process.get({__MODULE__, :inspect_run}, {:error, :not_found})
  end

  @impl true
  def inspect_run_graph(_run_id, _opts) do
    Process.get({__MODULE__, :inspect_run_graph}, {:error, :not_found})
  end

  @impl true
  def explain_run(_run_id, _opts) do
    Process.get({__MODULE__, :explain_run}, {:error, :not_found})
  end

  @impl true
  def cancel(_run_id, _opts) do
    Process.get({__MODULE__, :cancel}, {:error, :not_found})
  end

  @impl true
  def resume(_run_id, _attrs, _opts) do
    Process.get({__MODULE__, :resume}, {:error, :not_found})
  end

  @impl true
  def approve(_run_id, _attrs, _opts) do
    Process.get({__MODULE__, :approve}, {:error, :not_found})
  end

  @impl true
  def reject(_run_id, _attrs, _opts) do
    Process.get({__MODULE__, :reject}, {:error, :not_found})
  end

  @impl true
  def replay(_run_id, _opts) do
    Process.get({__MODULE__, :replay}, {:error, :not_found})
  end

  def put_list_runs(result), do: Process.put({__MODULE__, :list_runs}, result)
  def put_inspect_run(result), do: Process.put({__MODULE__, :inspect_run}, result)
  def put_inspect_run_graph(result), do: Process.put({__MODULE__, :inspect_run_graph}, result)
  def put_explain_run(result), do: Process.put({__MODULE__, :explain_run}, result)
  def put_cancel(result), do: Process.put({__MODULE__, :cancel}, result)
  def put_resume(result), do: Process.put({__MODULE__, :resume}, result)
  def put_approve(result), do: Process.put({__MODULE__, :approve}, result)
  def put_reject(result), do: Process.put({__MODULE__, :reject}, result)
  def put_replay(result), do: Process.put({__MODULE__, :replay}, result)
end
