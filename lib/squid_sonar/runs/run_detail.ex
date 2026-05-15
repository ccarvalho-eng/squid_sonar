defmodule SquidSonar.Runs.RunDetail do
  @moduledoc """
  Detailed run projection for the run detail view.
  """

  alias SquidMesh.Run
  alias SquidMesh.RunExplanation
  alias SquidSonar.Runs.RunSummary
  alias SquidSonar.Runs.WorkflowGraph

  @type t :: %__MODULE__{
          summary: RunSummary.t(),
          payload: map() | nil,
          context: map() | nil,
          last_error: map() | nil,
          step_runs: [term()],
          audit_events: [term()],
          workflow_graph: WorkflowGraph.t(),
          explanation: RunExplanation.t()
        }

  defstruct [
    :summary,
    :payload,
    :context,
    :last_error,
    :explanation,
    :workflow_graph,
    step_runs: [],
    audit_events: []
  ]

  @doc false
  @spec from_run(Run.t(), RunExplanation.t()) :: t()
  def from_run(%Run{} = run, %RunExplanation{} = explanation) do
    %__MODULE__{
      summary: RunSummary.from_run(run),
      payload: run.payload,
      context: run.context,
      last_error: run.last_error,
      step_runs: List.wrap(run.step_runs),
      audit_events: List.wrap(run.audit_events),
      workflow_graph: WorkflowGraph.from_run(run, explanation),
      explanation: explanation
    }
  end
end
