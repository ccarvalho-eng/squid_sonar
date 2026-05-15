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
          step_attempts: [map()],
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
    step_attempts: [],
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
      step_attempts: step_attempts(run.step_runs),
      audit_events: List.wrap(run.audit_events),
      workflow_graph: WorkflowGraph.from_run(run, explanation),
      explanation: explanation
    }
  end

  defp step_attempts(step_runs) do
    step_runs
    |> List.wrap()
    |> Enum.flat_map(&attempt_summaries/1)
  end

  defp attempt_summaries(%{attempts: attempts} = step_run) do
    attempts
    |> List.wrap()
    |> Enum.map(&attempt_summary(step_run, &1))
  end

  defp attempt_summaries(_step_run), do: []

  defp attempt_summary(%{step: step}, %{
         attempt_number: attempt_number,
         status: status,
         error: error,
         inserted_at: inserted_at,
         updated_at: updated_at
       }) do
    %{
      step: step,
      attempt_number: attempt_number,
      status: status,
      error: error,
      inserted_at: inserted_at,
      updated_at: updated_at
    }
  end

  defp attempt_summary(%{step: step}, attempt) do
    %{
      step: step,
      attempt_number: attempt_field(attempt, :attempt_number),
      status: attempt_field(attempt, :status),
      error: attempt_field(attempt, :error),
      inserted_at: attempt_field(attempt, :inserted_at),
      updated_at: attempt_field(attempt, :updated_at)
    }
  end

  defp attempt_field(%{attempt_number: value}, :attempt_number), do: value
  defp attempt_field(%{status: value}, :status), do: value
  defp attempt_field(%{error: value}, :error), do: value
  defp attempt_field(%{inserted_at: value}, :inserted_at), do: value
  defp attempt_field(%{updated_at: value}, :updated_at), do: value
  defp attempt_field(_attempt, _field), do: nil
end
