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
  def explain_run(_run_id, _opts) do
    Process.get({__MODULE__, :explain_run}, {:error, :not_found})
  end

  def put_list_runs(result), do: Process.put({__MODULE__, :list_runs}, result)
  def put_inspect_run(result), do: Process.put({__MODULE__, :inspect_run}, result)
  def put_explain_run(result), do: Process.put({__MODULE__, :explain_run}, result)
end
