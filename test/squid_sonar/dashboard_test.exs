defmodule SquidSonar.DashboardTest do
  use ExUnit.Case, async: true

  alias SquidMesh.Run
  alias SquidSonar.Dashboard
  alias SquidSonar.FakeSquidMeshClient

  @loaded_at ~U[2026-05-15 10:30:00Z]

  test "loads recent runs with status counts" do
    FakeSquidMeshClient.put_list_runs(
      {:ok,
       [
         run(:completed),
         run(:failed),
         run(:failed),
         run(:retrying),
         run(:paused),
         run(:running)
       ]}
    )

    dashboard = Dashboard.load(client: FakeSquidMeshClient, loaded_at: @loaded_at)

    assert length(dashboard.runs) == 6
    assert dashboard.loaded_at == @loaded_at
    assert dashboard.load_error == nil
    assert dashboard.status_counts.completed == 1
    assert dashboard.status_counts.failed == 2
    assert dashboard.status_counts.retrying == 1
    assert dashboard.status_counts.paused == 1
    assert dashboard.status_counts.running == 1
    assert dashboard.loaded_count == 6
    assert dashboard.filtered_count == 6
    assert dashboard.charts.activity.title == "Run activity"
    assert dashboard.charts.latency.title == "Runtime latency"
  end

  test "builds operational chart data from recent runs" do
    FakeSquidMeshClient.put_list_runs(
      {:ok,
       [
         run(:completed,
           id: "completed-fast",
           inserted_at: ~U[2026-05-15 10:00:00Z],
           updated_at: ~U[2026-05-15 10:01:00Z]
         ),
         run(:completed,
           id: "completed-slow",
           inserted_at: ~U[2026-05-15 10:00:00Z],
           updated_at: ~U[2026-05-15 10:03:00Z]
         ),
         run(:failed,
           id: "failed-run",
           inserted_at: ~U[2026-05-14 10:00:00Z],
           updated_at: ~U[2026-05-14 10:02:00Z]
         ),
         run(:running,
           id: "running-run",
           inserted_at: ~U[2026-05-15 10:00:00Z],
           updated_at: ~U[2026-05-15 10:04:00Z]
         )
       ]}
    )

    dashboard = Dashboard.load(client: FakeSquidMeshClient, loaded_at: @loaded_at)

    assert dashboard.charts.activity.kind == :bar
    assert dashboard.charts.activity.summary == %{value: 4, label: "runs in 7 days"}

    assert dashboard.charts.activity.labels == [
             "May 09",
             "May 10",
             "May 11",
             "May 12",
             "May 13",
             "May 14",
             "May 15"
           ]

    assert dashboard.charts.activity.series == [
             %{label: "Total", values: [0, 0, 0, 0, 0, 1, 3]},
             %{label: "Failed", values: [0, 0, 0, 0, 0, 1, 0]}
           ]

    assert dashboard.charts.latency.kind == :bar
    assert dashboard.charts.latency.summary == %{value: 180, label: "p95 runtime"}
    assert dashboard.charts.latency.labels == dashboard.charts.activity.labels

    assert dashboard.charts.latency.series == [
             %{label: "Median", values: [nil, nil, nil, nil, nil, 120, 60]},
             %{label: "P95", values: [nil, nil, nil, nil, nil, 120, 180]}
           ]
  end

  test "builds chart data from the filtered run set" do
    FakeSquidMeshClient.put_list_runs(
      {:ok,
       [
         run(:completed,
           id: "completed-run",
           inserted_at: ~U[2026-05-15 10:00:00Z],
           updated_at: ~U[2026-05-15 10:01:00Z]
         ),
         run(:failed,
           id: "failed-run",
           inserted_at: ~U[2026-05-15 10:00:00Z],
           updated_at: ~U[2026-05-15 10:02:00Z]
         )
       ]}
    )

    dashboard =
      Dashboard.load(
        client: FakeSquidMeshClient,
        loaded_at: @loaded_at,
        filters: %{"status" => "failed"}
      )

    assert dashboard.filtered_count == 1
    assert dashboard.charts.activity.summary == %{value: 1, label: "runs in 7 days"}

    assert [
             %{label: "Total", values: [0, 0, 0, 0, 0, 0, 1]},
             %{label: "Failed", values: [0, 0, 0, 0, 0, 0, 1]}
           ] = dashboard.charts.activity.series

    assert dashboard.charts.latency.summary == %{value: 120, label: "p95 runtime"}
  end

  test "filters runs by status while preserving date order" do
    FakeSquidMeshClient.put_list_runs(
      {:ok,
       [
         run(:completed, updated_at: ~U[2026-05-15 10:00:00Z]),
         run(:failed, id: "failed-old", updated_at: ~U[2026-05-15 10:01:00Z]),
         run(:failed, id: "failed-new", updated_at: ~U[2026-05-15 10:03:00Z]),
         run(:running, updated_at: ~U[2026-05-15 10:02:00Z])
       ]}
    )

    dashboard =
      Dashboard.load(
        client: FakeSquidMeshClient,
        loaded_at: @loaded_at,
        filters: %{"status" => "failed"}
      )

    assert Enum.map(dashboard.runs, & &1.status) == [:failed, :failed]
    assert Enum.map(dashboard.runs, & &1.id) == ["failed-new", "failed-old"]
    assert dashboard.filtered_count == 2
    assert dashboard.loaded_count == 4
    assert dashboard.status_counts.completed == 1
  end

  test "paginates filtered runs" do
    runs =
      for index <- 1..12 do
        run(:failed,
          id: "run-#{index}",
          updated_at: DateTime.add(@loaded_at, index, :second)
        )
      end

    FakeSquidMeshClient.put_list_runs({:ok, runs})

    dashboard =
      Dashboard.load(
        client: FakeSquidMeshClient,
        loaded_at: @loaded_at,
        filters: %{"status" => "failed"},
        page: "2",
        page_size: "10"
      )

    assert dashboard.page == 2
    assert dashboard.page_size == 10
    assert dashboard.total_pages == 2
    assert dashboard.filtered_count == 12
    assert Enum.map(dashboard.runs, & &1.id) == ["run-2", "run-1"]
  end

  test "filters runs by dashboard search text" do
    FakeSquidMeshClient.put_list_runs(
      {:ok,
       [
         run(:completed),
         run(:failed),
         run(:running, current_step: :capture_payment)
       ]}
    )

    dashboard =
      Dashboard.load(
        client: FakeSquidMeshClient,
        loaded_at: @loaded_at,
        filters: %{"query" => "capture"}
      )

    assert [%{status: :running, current_step: :capture_payment}] = dashboard.runs
  end

  test "keeps error state at the dashboard boundary" do
    FakeSquidMeshClient.put_list_runs({:error, {:missing_config, [:repo]}})

    dashboard = Dashboard.load(client: FakeSquidMeshClient, loaded_at: @loaded_at)

    assert dashboard.runs == []
    assert dashboard.status_counts.failed == 0
    assert dashboard.load_error == {:missing_config, [:repo]}
  end

  defp run(status, attrs \\ []) do
    %Run{
      id: Keyword.get(attrs, :id, "#{status}-run"),
      workflow: ExampleWorkflow,
      trigger: Keyword.get(attrs, :trigger, :manual),
      status: status,
      current_step: Keyword.get(attrs, :current_step),
      inserted_at: Keyword.get(attrs, :inserted_at, @loaded_at),
      updated_at: Keyword.get(attrs, :updated_at, @loaded_at)
    }
  end
end
