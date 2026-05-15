defmodule SquidSonarExample.SquidMeshExecutor do
  @moduledoc false

  @behaviour SquidMesh.Executor

  alias SquidMesh.Executor.Payload
  alias SquidMesh.Runtime.Runner

  @impl true
  def enqueue_step(_config, run, step, opts) do
    run
    |> Payload.step(step)
    |> enqueue_payload(opts)
  end

  @impl true
  def enqueue_steps(_config, run, steps, opts) do
    results =
      Enum.map(steps, fn step ->
        run
        |> Payload.step(step)
        |> enqueue_payload(opts)
      end)

    if Enum.all?(results, &match?({:ok, _metadata}, &1)) do
      {:ok, Enum.map(results, fn {:ok, metadata} -> metadata end)}
    else
      {:error, {:enqueue_failed, results}}
    end
  end

  @impl true
  def enqueue_compensation(_config, run, opts) do
    run
    |> Payload.compensation()
    |> enqueue_payload(opts)
  end

  @impl true
  def enqueue_cron(_config, workflow, trigger, opts) do
    workflow
    |> Payload.cron(trigger)
    |> enqueue_payload(opts)
  end

  defp enqueue_payload(payload, opts) do
    schedule_in = Keyword.get(opts, :schedule_in, 0)

    case Task.Supervisor.start_child(SquidSonarExample.SquidMeshTaskSupervisor, fn ->
           maybe_sleep(schedule_in)
           Runner.perform(payload)
         end) do
      {:ok, pid} ->
        {:ok,
         %{
           executor: __MODULE__,
           pid: inspect(pid),
           schedule_in: schedule_in
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp maybe_sleep(schedule_in) when is_integer(schedule_in) and schedule_in > 0 do
    Process.sleep(:timer.seconds(schedule_in))
  end

  defp maybe_sleep(_schedule_in), do: Process.sleep(25)
end
