defmodule SquidSonarExample.SquidMeshExecutor do
  @moduledoc false

  @behaviour SquidMesh.Executor

  @impl true
  def enqueue_step(_config, _run, _step, _opts) do
    {:error, :example_executor_not_started}
  end

  @impl true
  def enqueue_steps(_config, _run, _steps, _opts) do
    {:error, :example_executor_not_started}
  end

  @impl true
  def enqueue_compensation(_config, _run, _opts) do
    {:error, :example_executor_not_started}
  end

  @impl true
  def enqueue_cron(_config, _workflow, _trigger, _opts) do
    {:error, :example_executor_not_started}
  end
end
