defmodule SquidSonar.Runs.WorkflowGraph do
  @moduledoc """
  Workflow graph projection for run detail views.
  """

  alias SquidMesh.ReadModel.Inspection.Snapshot
  alias SquidMesh.Runs.GraphInspection
  alias SquidMesh.Workflow.Definition

  defmodule Node do
    @moduledoc false

    @type t :: %__MODULE__{
            name: atom() | String.t(),
            label: String.t(),
            status: atom(),
            current?: boolean(),
            terminal?: boolean(),
            recovery: map() | nil
          }

    defstruct [:name, :label, :status, :recovery, current?: false, terminal?: false]
  end

  defmodule Edge do
    @moduledoc false

    @type t :: %__MODULE__{
            from: atom() | String.t(),
            to: atom() | String.t(),
            outcome: atom(),
            recovery: atom() | nil
          }

    defstruct [:from, :to, :outcome, :recovery]
  end

  @type t :: %__MODULE__{
          available?: boolean(),
          mode: :transition | :dependency | :history,
          nodes: [struct()],
          edges: [struct()]
        }

  defstruct available?: false, mode: :history, nodes: [], edges: []

  @doc false
  @spec from_models(Snapshot.t(), GraphInspection.t()) :: t()
  def from_models(%Snapshot{} = snapshot, %GraphInspection{} = graph_inspection) do
    %__MODULE__{
      available?: graph_inspection.nodes != [],
      mode: graph_mode(snapshot.workflow),
      nodes: Enum.map(graph_inspection.nodes, &graph_node/1),
      edges: Enum.map(graph_inspection.edges, &graph_edge/1)
    }
  end

  defp graph_mode(workflow) do
    with {:ok, definition} <- load_definition(workflow) do
      if Definition.dependency_mode?(definition), do: :dependency, else: :transition
    else
      _ -> :history
    end
  end

  defp load_definition(workflow) when is_atom(workflow), do: Definition.load(workflow)

  defp load_definition(workflow) when is_binary(workflow) do
    case Definition.load_serialized(workflow) do
      {:ok, _workflow, definition} -> {:ok, definition}
      {:error, _reason} = error -> error
    end
  end

  defp load_definition(_workflow), do: {:error, {:invalid_workflow, nil}}

  defp graph_node(%{id: id, status: status, current?: current?} = node) do
    %Node{
      name: id,
      label: format_name(id),
      status: status,
      recovery: Map.get(node, :recovery),
      current?: current?,
      terminal?: terminal_node?(id, status)
    }
  end

  defp graph_edge(%{from: from, to: to, outcome: outcome, recovery: recovery}) do
    %Edge{from: from, to: to, outcome: outcome, recovery: recovery}
  end

  defp terminal_node?(id, status) do
    id == "complete" or status in [:completed, :failed, :cancelled]
  end

  defp format_name(step_name) do
    step_name
    |> to_string()
    |> String.replace_prefix("Elixir.", "")
  end
end
