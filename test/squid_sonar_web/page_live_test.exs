defmodule SquidSonarWeb.PageLiveTest do
  use ExUnit.Case, async: false

  import Phoenix.LiveViewTest

  alias Phoenix.LiveView.Socket
  alias SquidMesh.Run
  alias SquidSonar.FakeSquidMeshClient
  alias SquidSonarWeb.PageLive

  setup do
    previous_client = Application.get_env(:squid_sonar, :squid_mesh_client)
    Application.put_env(:squid_sonar, :squid_mesh_client, FakeSquidMeshClient)

    on_exit(fn ->
      if previous_client do
        Application.put_env(:squid_sonar, :squid_mesh_client, previous_client)
      else
        Application.delete_env(:squid_sonar, :squid_mesh_client)
      end
    end)
  end

  test "renders run status counts and recent workflow runs" do
    FakeSquidMeshClient.put_list_runs(
      {:ok,
       [
         run(:completed, :completed_checkout, nil),
         run(:failed, :failing_checkout, :fail_payment),
         run(:retrying, :retrying_checkout, :retry_once),
         run(:paused, :manual_review_checkout, :wait_for_review)
       ]}
    )

    html = render_page()

    assert html =~ "SquidSonar"
    assert html =~ "Runtime dashboard"
    assert html =~ "phx-hook=\"SquidSonarTheme\""
    assert html =~ "phx-hook=\"SquidSonarChart\""
    assert html =~ "squid-sonar-chart-tooltip"
    assert html =~ "Run activity"
    assert html =~ "Latency"
    assert html =~ "runs in 7 days"
    assert html =~ "matching runs"
    assert html =~ "Workflow runs"
    assert html =~ "squid-sonar-filter-toggle"
    assert html =~ "Filters"
    refute html =~ "squid-sonar-overview"
    refute html =~ "squid-sonar-status-chart"
    refute html =~ "Status distribution"
    assert html =~ "Search"
    assert html =~ "Page size"
    assert html =~ "Refresh runs"
    assert html =~ "Failed"
    assert html =~ "Completed"
    assert html =~ "Retrying"
    assert html =~ "Paused"
    assert html =~ "Running"
    assert html =~ "Recent runs"
    assert html =~ "completed_checkout"
    assert html =~ "failing_checkout"
    assert html =~ "retry_once"
    assert html =~ "wait_for_review"
  end

  test "renders an empty state when no runs are available" do
    FakeSquidMeshClient.put_list_runs({:ok, []})

    html = render_page()

    assert html =~ "No runs found"
  end

  test "renders a boundary error when runs cannot be loaded" do
    FakeSquidMeshClient.put_list_runs({:error, {:missing_config, [:repo]}})

    html = render_page()

    assert html =~ "Unable to load runs"
    refute html =~ "missing_config"
  end

  test "filters run sections through the LiveView boundary" do
    FakeSquidMeshClient.put_list_runs(
      {:ok,
       [
         run(:completed, :completed_checkout, nil),
         run(:failed, :failing_checkout, :fail_payment)
       ]}
    )

    {:ok, socket} = PageLive.mount(%{}, %{}, %Socket{})

    {:noreply, socket} =
      PageLive.handle_event("filter", %{"filters" => %{"status" => "failed"}}, socket)

    html =
      socket.assigns
      |> PageLive.render()
      |> rendered_to_string()

    assert html =~ "failing_checkout"
    refute html =~ "completed_checkout"
  end

  test "toggles the dashboard chart through the LiveView boundary" do
    FakeSquidMeshClient.put_list_runs({:ok, [run(:completed, :completed_checkout, nil)]})

    {:ok, socket} = PageLive.mount(%{}, %{}, %Socket{})
    {:noreply, socket} = PageLive.handle_event("set_chart", %{"chart" => "latency"}, socket)

    html =
      socket.assigns
      |> PageLive.render()
      |> rendered_to_string()

    assert html =~ "Runtime latency"
    assert html =~ "p95 runtime"
    assert html =~ "is-active"
  end

  test "paginates runs through the dashboard boundary" do
    runs =
      for index <- 1..12 do
        %Run{
          id: "run-#{index}",
          workflow: SquidSonarExampleWorkflow,
          trigger: :manual,
          status: :failed,
          current_step: :fail_payment,
          inserted_at: ~U[2026-05-15 10:00:00Z],
          updated_at: DateTime.add(~U[2026-05-15 10:00:00Z], index, :second)
        }
      end

    FakeSquidMeshClient.put_list_runs({:ok, runs})

    {:ok, socket} = PageLive.mount(%{}, %{}, %Socket{})
    {:noreply, socket} = PageLive.handle_event("paginate", %{"page" => "2"}, socket)

    html =
      socket.assigns
      |> PageLive.render()
      |> rendered_to_string()

    assert html =~ "2 / 2"
    assert html =~ "run-2"
    refute html =~ "run-12"
  end

  test "sets dashboard theme without reloading run data" do
    FakeSquidMeshClient.put_list_runs({:ok, [run(:failed, :failing_checkout, :fail_payment)]})

    {:ok, socket} = PageLive.mount(%{}, %{}, %Socket{})
    {:noreply, socket} = PageLive.handle_event("set_theme", %{"theme" => "dark"}, socket)

    html =
      socket.assigns
      |> PageLive.render()
      |> rendered_to_string()

    assert html =~ "squid-sonar-theme-dark"
    assert html =~ "failing_checkout"
  end

  defp render_page do
    {:ok, socket} = PageLive.mount(%{}, %{}, %Socket{})

    socket.assigns
    |> PageLive.render()
    |> rendered_to_string()
  end

  defp run(status, trigger, current_step) do
    %Run{
      id: "#{trigger}-run",
      workflow: SquidSonarExampleWorkflow,
      trigger: trigger,
      status: status,
      current_step: current_step,
      inserted_at: ~U[2026-05-15 10:00:00Z],
      updated_at: ~U[2026-05-15 10:01:00Z]
    }
  end
end
