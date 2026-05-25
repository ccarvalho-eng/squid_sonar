defmodule SquidSonarWeb.RunLiveTest do
  use ExUnit.Case, async: false

  import SquidSonar.ReadModelFixtures

  defmodule CheckoutWorkflow do
    use SquidMesh.Workflow

    workflow do
      trigger :manual do
        manual()
      end

      step(:load_order, :log, message: "load order")
      step(:capture_payment, :log, message: "capture payment")
      step(:send_receipt, :log, message: "send receipt")

      transition(:load_order, on: :ok, to: :capture_payment)
      transition(:capture_payment, on: :ok, to: :send_receipt)
      transition(:send_receipt, on: :ok, to: :complete)
    end
  end

  defmodule MissingWorkflow do
  end

  import Phoenix.LiveViewTest

  alias Phoenix.LiveView.Socket
  alias SquidSonar.FakeSquidMeshClient
  alias SquidSonarWeb.RunLive

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

  test "renders run detail through the run context" do
    snapshot =
      snapshot(:running,
        run_id: "run-1",
        workflow: Atom.to_string(CheckoutWorkflow),
        current_step: "capture_payment",
        reason: :attempt_visible,
        attempts: [attempt("capture_payment", :claimed, 1, %{"message" => "Gateway unavailable"})],
        planned_runnables: [%{runnable_key: "capture_payment"}],
        anomalies: [%{kind: :stale_projection}]
      )

    graph =
      graph_inspection(:running,
        run_id: "run-1",
        workflow: Atom.to_string(CheckoutWorkflow),
        current_node_id: "capture_payment",
        nodes: [
          graph_node("load_order", :completed, false),
          graph_node("capture_payment", :running, true),
          graph_node("send_receipt", :waiting, false)
        ],
        edges: [
          graph_edge("load_order", "capture_payment", :ok),
          graph_edge("capture_payment", "send_receipt", :ok)
        ]
      )

    explanation =
      diagnostic(
        :running,
        run_id: "run-1",
        workflow: Atom.to_string(CheckoutWorkflow),
        reason: :attempt_visible,
        step: "capture_payment",
        summary: "A dispatch attempt is visible and waiting for a worker claim.",
        details: %{visible_attempt_count: 1},
        next_actions: [:wait_for_worker_claim],
        evidence: %{attempt_counts: %{claimed: 1}}
      )

    FakeSquidMeshClient.put_inspect_run({:ok, snapshot})
    FakeSquidMeshClient.put_inspect_run_graph({:ok, graph})
    FakeSquidMeshClient.put_explain_run({:ok, explanation})

    {:ok, socket} = RunLive.mount(%{}, %{}, %Socket{})
    {:noreply, socket} = RunLive.handle_params(%{"id" => "run-1"}, "/sonar/runs/run-1", socket)

    html =
      socket.assigns
      |> RunLive.render()
      |> rendered_to_string()

    assert html =~ "SquidSonar"
    assert html =~ "Run detail"
    assert html =~ "Run summary"
    assert html =~ "Journal-backed runtime"
    assert html =~ "CheckoutWorkflow"
    assert html =~ "capture_payment"
    assert html =~ "Queue"
    assert html =~ "Status"
    assert html =~ "Thread revisions"
    assert html =~ "Transition graph"
    assert html =~ "Journal evidence"
    assert html =~ "Planned runnables"
    assert html =~ "Attempts"
    assert html =~ "Anomalies"
    assert html =~ "Gateway unavailable"
    assert html =~ "wait_for_worker_claim"
    assert html =~ "squid-sonar-workflow-graph"
  end

  test "renders journal history graphs when the workflow definition is unavailable" do
    snapshot =
      snapshot(:completed,
        run_id: "run-history",
        workflow: Atom.to_string(MissingWorkflow),
        current_step: "capture_payment",
        reason: :terminal,
        attempts: [
          attempt("load_order", :completed, 1, nil),
          attempt("capture_payment", :completed, 1, nil)
        ]
      )

    graph =
      graph_inspection(:completed,
        run_id: "run-history",
        workflow: Atom.to_string(MissingWorkflow),
        current_node_id: "capture_payment",
        nodes: [
          graph_node("load_order", :completed, false),
          graph_node("capture_payment", :completed, true)
        ],
        edges: [
          graph_edge("load_order", "capture_payment", :next)
        ]
      )

    explanation =
      diagnostic(
        :completed,
        run_id: "run-history",
        workflow: Atom.to_string(MissingWorkflow),
        reason: :terminal,
        step: "capture_payment",
        summary: "The run is terminal according to the run journal.",
        details: %{terminal?: true, terminal_status: :completed},
        next_actions: [:inspect_terminal_run],
        evidence: %{terminal_status: :completed}
      )

    FakeSquidMeshClient.put_inspect_run({:ok, snapshot})
    FakeSquidMeshClient.put_inspect_run_graph({:ok, graph})
    FakeSquidMeshClient.put_explain_run({:ok, explanation})

    {:ok, socket} = RunLive.mount(%{}, %{}, %Socket{})

    {:noreply, socket} =
      RunLive.handle_params(%{"id" => "run-history"}, "/sonar/runs/run-history", socket)

    html =
      socket.assigns
      |> RunLive.render()
      |> rendered_to_string()

    assert html =~ "Journal-backed runtime"
    assert html =~ "History graph"
    assert html =~ "Journal evidence"
    assert html =~ "load_order"
    assert html =~ "capture_payment"
  end

  test "renders load errors without leaking internal reason details" do
    FakeSquidMeshClient.put_inspect_run({:error, {:missing_config, [:repo]}})

    {:ok, socket} = RunLive.mount(%{}, %{}, %Socket{})
    {:noreply, socket} = RunLive.handle_params(%{"id" => "bad"}, "/sonar/runs/bad", socket)

    html =
      socket.assigns
      |> RunLive.render()
      |> rendered_to_string()

    assert html =~ "Unable to load runs"
    refute html =~ "missing_config"
  end
end
