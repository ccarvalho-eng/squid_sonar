defmodule Mix.Tasks.Example.Seed do
  @moduledoc """
  Seeds monitorable Squid Mesh runs for the example app.
  """

  use Mix.Task

  @shortdoc "Seeds example Squid Mesh workflow runs"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    run_ids =
      scenarios()
      |> Enum.flat_map(&start_scenario/1)

    Process.sleep(250)

    runs =
      Enum.map(run_ids, fn run_id ->
        {:ok, run} = SquidMesh.inspect_run(run_id)
        run
      end)

    Mix.shell().info("""

    Seeded Squid Mesh example runs.

    Current run statuses:
    #{format_runs(runs)}

    Open /sonar in the example app to inspect them.
    """)
  end

  defp scenarios do
    unique = System.system_time(:millisecond)

    [
      {SquidSonarExample.Workflows.CompletedCheckout, :completed_checkout,
       %{order_id: "order-complete-#{unique}", customer_id: "cust_demo"}},
      {SquidSonarExample.Workflows.FailingCheckout, :failing_checkout,
       %{order_id: "order-failed-#{unique}", customer_id: "cust_demo"}},
      {SquidSonarExample.Workflows.RetryingCheckout, :retrying_checkout,
       %{order_id: "order-retrying-#{unique}", customer_id: "cust_demo"}},
      {SquidSonarExample.Workflows.ManualReviewCheckout, :manual_review_checkout,
       %{order_id: "order-review-#{unique}", customer_id: "cust_demo"}}
    ]
  end

  defp start_scenario({workflow, trigger, payload}) do
    case SquidMesh.start_run(workflow, trigger, payload) do
      {:ok, run} ->
        Mix.shell().info("* started #{inspect(workflow)} #{run.id}")
        [run.id]

      {:error, reason} ->
        Mix.shell().error("* failed #{inspect(workflow)}: #{inspect(reason)}")
        []
    end
  end

  defp format_runs(runs) do
    runs
    |> Enum.map_join("\n", fn run ->
      "  * #{inspect(run.workflow)} #{run.status} current_step=#{inspect(run.current_step)}"
    end)
  end
end
