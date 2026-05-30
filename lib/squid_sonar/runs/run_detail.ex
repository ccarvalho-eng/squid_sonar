defmodule SquidSonar.Runs.RunDetail do
  @moduledoc """
  Detailed run projection for the run detail view.
  """

  alias SquidMesh.ReadModel.Explanation.Diagnostic
  alias SquidMesh.ReadModel.Inspection.Snapshot
  alias SquidMesh.Runs.GraphInspection
  alias SquidSonar.Runs.WorkflowGraph

  defmodule Summary do
    @moduledoc false

    @type t :: %__MODULE__{
            id: String.t(),
            workflow: String.t() | module() | nil,
            queue: String.t(),
            status: atom(),
            current_step: String.t() | nil,
            reason: atom(),
            terminal?: boolean(),
            terminal_status: atom() | nil,
            thread_revisions: %{run: non_neg_integer(), dispatch: non_neg_integer()}
          }

    @enforce_keys [
      :id,
      :workflow,
      :queue,
      :status,
      :current_step,
      :reason,
      :terminal?,
      :terminal_status,
      :thread_revisions
    ]

    defstruct [
      :id,
      :workflow,
      :queue,
      :status,
      :current_step,
      :reason,
      :terminal?,
      :terminal_status,
      :thread_revisions
    ]
  end

  @type t :: %__MODULE__{
          summary: Summary.t(),
          payload: map() | nil,
          context: map(),
          last_error: map() | nil,
          planned_runnables: [map()],
          attempts: [map()],
          anomalies: [map()],
          graph_inspection: map(),
          workflow_graph: WorkflowGraph.t(),
          explanation: Diagnostic.t()
        }

  defstruct [
    :summary,
    :payload,
    :context,
    :last_error,
    :explanation,
    :graph_inspection,
    :workflow_graph,
    planned_runnables: [],
    attempts: [],
    anomalies: []
  ]

  @doc false
  @spec from_models(Snapshot.t(), Diagnostic.t(), GraphInspection.t()) :: t()
  def from_models(%Snapshot{} = snapshot, %Diagnostic{} = explanation, %GraphInspection{} = graph) do
    %__MODULE__{
      summary: summary(snapshot, explanation, graph),
      payload: snapshot.input,
      context: snapshot.context,
      last_error: latest_error(snapshot.attempts),
      planned_runnables: List.wrap(snapshot.planned_runnables),
      attempts: List.wrap(snapshot.attempts),
      anomalies: List.wrap(snapshot.anomalies),
      graph_inspection: GraphInspection.to_map(graph),
      workflow_graph: WorkflowGraph.from_models(snapshot, graph),
      explanation: explanation
    }
  end

  defp summary(%Snapshot{} = snapshot, %Diagnostic{} = explanation, %GraphInspection{} = graph) do
    %Summary{
      id: snapshot.run_id,
      workflow: snapshot.workflow,
      queue: snapshot.queue,
      status: snapshot.status,
      current_step: graph.current_node_id || explanation.step,
      reason: snapshot.reason,
      terminal?: snapshot.terminal?,
      terminal_status: snapshot.terminal_status,
      thread_revisions: snapshot.thread_revisions
    }
  end

  defp latest_error(attempts) do
    attempts
    |> List.wrap()
    |> Enum.reverse()
    |> Enum.find_value(fn attempt -> Map.get(attempt, :error) end)
  end
end
