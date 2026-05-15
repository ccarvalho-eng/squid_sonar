defmodule SquidSonar.Runs.WorkflowGraph do
  @moduledoc """
  Workflow graph projection for run detail views.
  """

  alias SquidMesh.Run
  alias SquidMesh.RunExplanation
  alias SquidMesh.Workflow.Definition

  defmodule Node do
    @moduledoc false

    @type t :: %__MODULE__{
            name: atom() | String.t(),
            label: String.t(),
            status: atom(),
            current?: boolean(),
            terminal?: boolean()
          }

    defstruct [:name, :label, :status, current?: false, terminal?: false]
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
  @spec from_run(Run.t(), RunExplanation.t() | nil) :: t()
  def from_run(%Run{} = run, explanation \\ nil) do
    with {:ok, definition} <- Definition.load(run.workflow) do
      from_definition(run, explanation, definition)
    else
      {:error, _reason} -> from_history(run)
    end
  end

  defp from_definition(run, explanation, definition) do
    mode = graph_mode(definition)
    statuses = step_statuses(run, explanation)
    inspected_steps = Definition.inspect_steps(definition, statuses)

    nodes =
      inspected_steps
      |> Enum.map(fn inspected_step ->
        node(
          inspected_step.step,
          display_status(inspected_step.step, inspected_step.status, run),
          run
        )
      end)
      |> maybe_append_complete_node(run, definition)

    %__MODULE__{
      available?: true,
      mode: mode,
      nodes: nodes,
      edges: edges(definition, inspected_steps, mode)
    }
  end

  defp graph_mode(definition) do
    if Definition.dependency_mode?(definition), do: :dependency, else: :transition
  end

  defp step_statuses(run, explanation) do
    run
    |> persisted_step_statuses()
    |> Map.merge(explanation_step_statuses(explanation), fn _step, _status, fallback ->
      fallback
    end)
    |> Map.merge(current_step_status(run), fn _step, _status, current_status -> current_status end)
  end

  defp persisted_step_statuses(%{steps: steps}) when is_list(steps) and steps != [] do
    statuses_from_steps(steps)
  end

  defp persisted_step_statuses(%{step_runs: step_runs}) when is_list(step_runs) do
    statuses_from_steps(step_runs)
  end

  defp persisted_step_statuses(_run), do: %{}

  defp explanation_step_statuses(%RunExplanation{evidence: %{step_states: step_states}})
       when is_list(step_states) do
    statuses_from_steps(step_states)
  end

  defp explanation_step_statuses(_explanation), do: %{}

  defp statuses_from_steps(steps) do
    Map.new(steps, fn %{step: step_name, status: status} ->
      {serialized_step(step_name), status}
    end)
  end

  defp current_step_status(%{current_step: nil}), do: %{}

  defp current_step_status(%{current_step: current_step, status: status}) do
    %{serialized_step(current_step) => inspect_status(status)}
  end

  defp inspect_status(:failed), do: :failed
  defp inspect_status(:cancelled), do: :failed
  defp inspect_status(:completed), do: :completed
  defp inspect_status(:pending), do: :pending
  defp inspect_status(_status), do: :running

  defp maybe_append_complete_node(nodes, %{status: :completed} = run, definition) do
    if complete_target?(definition) do
      nodes ++ [terminal_node(:completed, run)]
    else
      nodes
    end
  end

  defp maybe_append_complete_node(nodes, run, definition) do
    if complete_target?(definition) do
      nodes ++ [terminal_node(:waiting, run)]
    else
      nodes
    end
  end

  defp complete_target?(definition) do
    Enum.any?(definition.transitions, &(&1.to == :complete))
  end

  defp terminal_node(status, run) do
    %Node{
      name: :complete,
      label: "complete",
      status: status,
      current?: run.current_step == :complete,
      terminal?: true
    }
  end

  defp node(step_name, status, run) do
    %Node{
      name: step_name,
      label: format_name(step_name),
      status: status,
      current?: current_step?(run.current_step, step_name)
    }
  end

  defp display_status(step_name, inspect_status, run) do
    if current_step?(run.current_step, step_name) do
      current_display_status(run.status, inspect_status)
    else
      inspect_status
    end
  end

  defp current_display_status(:retrying, _inspect_status), do: :retrying
  defp current_display_status(:paused, _inspect_status), do: :paused
  defp current_display_status(:cancelling, _inspect_status), do: :cancelled
  defp current_display_status(:cancelled, _inspect_status), do: :cancelled

  defp current_display_status(run_status, _inspect_status)
       when run_status in [:failed, :completed, :pending],
       do: run_status

  defp current_display_status(_run_status, inspect_status), do: inspect_status

  defp current_step?(nil, _step_name), do: false

  defp current_step?(current_step, step_name),
    do: serialized_step(current_step) == serialized_step(step_name)

  defp edges(definition, _inspected_steps, :transition) do
    Enum.map(definition.transitions, fn transition ->
      %Edge{
        from: transition.from,
        to: transition.to,
        outcome: transition.on,
        recovery: Map.get(transition, :recovery)
      }
    end)
  end

  defp edges(_definition, inspected_steps, :dependency) do
    inspected_steps
    |> Enum.flat_map(fn inspected_step ->
      Enum.map(inspected_step.depends_on, fn dependency ->
        %Edge{from: dependency, to: inspected_step.step, outcome: :ready}
      end)
    end)
  end

  defp from_history(run) do
    step_runs = List.wrap(run.step_runs)

    %__MODULE__{
      nodes:
        Enum.map(step_runs, fn %{step: step_name, status: status} ->
          node(step_name, status, run)
        end),
      edges: history_edges(step_runs)
    }
  end

  defp history_edges(step_runs) do
    step_runs
    |> Enum.map(fn %{step: step_name} -> step_name end)
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [from, to] -> %Edge{from: from, to: to, outcome: :next} end)
  end

  defp serialized_step(step), do: Definition.serialize_step(step)

  defp format_name(step_name) do
    step_name
    |> to_string()
    |> String.replace_prefix("Elixir.", "")
  end
end
