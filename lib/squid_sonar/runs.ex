defmodule SquidSonar.Runs do
  @moduledoc """
  Read boundary for Squid Mesh workflow runs.

  LiveViews should call this module instead of calling `SquidMesh` directly.
  That keeps runtime access, error handling, and view shaping in one place.
  """

  alias SquidSonar.Runs.RunDetail
  alias SquidSonar.Runs.RunSummary

  @type option :: {:client, module()} | {:squid_mesh, keyword()}

  @doc """
  Lists recent runs as UI-friendly summaries.
  """
  @spec list_runs(keyword(), [option()]) ::
          {:ok, [RunSummary.t()]} | {:error, term()}
  def list_runs(filters \\ [], opts \\ []) when is_list(filters) and is_list(opts) do
    client = client(opts)
    squid_mesh_opts = Keyword.get(opts, :squid_mesh, [])

    with {:ok, runs} <- client.list_runs(filters, squid_mesh_opts) do
      {:ok, Enum.map(runs, &RunSummary.from_summary/1)}
    end
  end

  @doc """
  Fetches one run with runtime snapshot, graph projection, and diagnostic explanation.
  """
  @spec get_run(term(), [option()]) :: {:ok, RunDetail.t()} | {:error, term()}
  def get_run(run_id, opts \\ []) when is_list(opts) do
    client = client(opts)
    squid_mesh_opts = Keyword.get(opts, :squid_mesh, [])

    with {:ok, snapshot} <- client.inspect_run(run_id, squid_mesh_opts),
         {:ok, graph} <- client.inspect_run_graph(run_id, squid_mesh_opts),
         {:ok, explanation} <- client.explain_run(run_id, squid_mesh_opts) do
      {:ok, RunDetail.from_models(snapshot, explanation, graph)}
    end
  end

  defp client(opts) do
    Keyword.get(
      opts,
      :client,
      Application.get_env(:squid_sonar, :squid_mesh_client, SquidSonar.SquidMeshClient)
    )
  end
end
