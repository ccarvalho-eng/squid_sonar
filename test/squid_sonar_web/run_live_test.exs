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
    assert html =~ "squid-sonar-workflow-panel-actions"
  end

  test "renders feedback after run control events" do
    snapshot =
      snapshot(:running,
        run_id: "run-1",
        workflow: Atom.to_string(CheckoutWorkflow),
        current_step: "capture_payment",
        reason: :attempt_visible
      )

    graph =
      graph_inspection(:running,
        run_id: "run-1",
        workflow: Atom.to_string(CheckoutWorkflow),
        current_node_id: "capture_payment",
        nodes: [
          graph_node("capture_payment", :running, true)
        ]
      )

    explanation =
      diagnostic(
        :running,
        run_id: "run-1",
        workflow: Atom.to_string(CheckoutWorkflow),
        reason: :attempt_visible,
        step: "capture_payment",
        next_actions: [:wait_for_worker_claim]
      )

    FakeSquidMeshClient.put_inspect_run({:ok, snapshot})
    FakeSquidMeshClient.put_inspect_run_graph({:ok, graph})
    FakeSquidMeshClient.put_explain_run({:ok, explanation})

    FakeSquidMeshClient.put_cancel(
      {:ok, snapshot(:cancelled, run_id: "run-1", workflow: Atom.to_string(CheckoutWorkflow))}
    )

    {:ok, socket} = RunLive.mount(%{}, %{}, %Socket{})
    {:noreply, socket} = RunLive.handle_params(%{"id" => "run-1"}, "/sonar/runs/run-1", socket)
    {:noreply, socket} = RunLive.handle_event("cancel", %{"run-id" => "run-1"}, socket)

    html =
      socket.assigns
      |> RunLive.render()
      |> rendered_to_string()

    assert html =~ "Run cancelled successfully"
    assert html =~ "phx-hook=\"SquidSonarFlash\""
    assert html =~ "aria-label=\"Dismiss notification\""

    {:noreply, socket} = RunLive.handle_event("clear_flash", %{}, socket)

    html =
      socket.assigns
      |> RunLive.render()
      |> rendered_to_string()

    refute html =~ "Run cancelled successfully"
  end

  test "renders approval controls without resume for approval pauses" do
    manual_state = %{step: "wait_for_review", kind: "approval"}

    snapshot =
      snapshot(:paused,
        run_id: "run-approval",
        workflow: Atom.to_string(CheckoutWorkflow),
        current_step: "wait_for_review",
        reason: :manual_intervention_required,
        manual_state: manual_state
      )

    graph =
      graph_inspection(:paused,
        run_id: "run-approval",
        workflow: Atom.to_string(CheckoutWorkflow),
        current_node_id: "wait_for_review",
        nodes: [
          graph_node("wait_for_review", :paused, true, manual_state: manual_state)
        ]
      )

    explanation =
      diagnostic(
        :paused,
        run_id: "run-approval",
        workflow: Atom.to_string(CheckoutWorkflow),
        reason: :manual_intervention_required,
        step: "wait_for_review",
        details: manual_state,
        next_actions: [:resolve_manual_step],
        evidence: %{manual_state: manual_state}
      )

    FakeSquidMeshClient.put_inspect_run({:ok, snapshot})
    FakeSquidMeshClient.put_inspect_run_graph({:ok, graph})
    FakeSquidMeshClient.put_explain_run({:ok, explanation})

    {:ok, socket} = RunLive.mount(%{}, %{}, %Socket{})

    {:noreply, socket} =
      RunLive.handle_params(%{"id" => "run-approval"}, "/sonar/runs/run-approval", socket)

    html =
      socket.assigns
      |> RunLive.render()
      |> rendered_to_string()

    assert html =~ "Approve"
    assert html =~ "Reject"
    refute html =~ "Resume"
  end

  test "passes the configured control actor to approval decisions" do
    actor = %{"id" => "user-123", "type" => "operator", "name" => "Ada"}
    parent = self()

    snapshot =
      snapshot(:paused,
        run_id: "run-approval",
        workflow: Atom.to_string(CheckoutWorkflow),
        current_step: "wait_for_review",
        reason: :manual_intervention_required,
        manual_state: %{step: "wait_for_review", kind: "approval"}
      )

    graph =
      graph_inspection(:paused,
        run_id: "run-approval",
        workflow: Atom.to_string(CheckoutWorkflow),
        current_node_id: "wait_for_review",
        nodes: [
          graph_node("wait_for_review", :paused, true)
        ]
      )

    explanation =
      diagnostic(
        :paused,
        run_id: "run-approval",
        workflow: Atom.to_string(CheckoutWorkflow),
        reason: :manual_intervention_required,
        step: "wait_for_review",
        details: %{step: "wait_for_review", kind: "approval"},
        next_actions: [:resolve_manual_step]
      )

    FakeSquidMeshClient.put_inspect_run({:ok, snapshot})
    FakeSquidMeshClient.put_inspect_run_graph({:ok, graph})
    FakeSquidMeshClient.put_explain_run({:ok, explanation})

    FakeSquidMeshClient.put_approve(fn run_id, attrs, _opts ->
      send(parent, {:approve_attrs, run_id, attrs})
      {:ok, snapshot(:running, run_id: run_id, workflow: Atom.to_string(CheckoutWorkflow))}
    end)

    {:ok, socket} = RunLive.mount(%{}, %{}, %Socket{})
    socket = Phoenix.Component.assign(socket, :control_actor, actor)

    {:noreply, socket} =
      RunLive.handle_params(%{"id" => "run-approval"}, "/sonar/runs/run-approval", socket)

    {:noreply, _socket} = RunLive.handle_event("approve", %{"run-id" => "run-approval"}, socket)

    assert_receive {:approve_attrs, "run-approval", %{actor: ^actor}}
  end

  test "renders control errors without leaking internal reason details" do
    snapshot =
      snapshot(:running,
        run_id: "run-1",
        workflow: Atom.to_string(CheckoutWorkflow),
        current_step: "capture_payment",
        reason: :attempt_visible
      )

    graph =
      graph_inspection(:running,
        run_id: "run-1",
        workflow: Atom.to_string(CheckoutWorkflow),
        current_node_id: "capture_payment",
        nodes: [
          graph_node("capture_payment", :running, true)
        ]
      )

    explanation =
      diagnostic(
        :running,
        run_id: "run-1",
        workflow: Atom.to_string(CheckoutWorkflow),
        reason: :attempt_visible,
        step: "capture_payment",
        next_actions: [:wait_for_worker_claim]
      )

    FakeSquidMeshClient.put_inspect_run({:ok, snapshot})
    FakeSquidMeshClient.put_inspect_run_graph({:ok, graph})
    FakeSquidMeshClient.put_explain_run({:ok, explanation})
    FakeSquidMeshClient.put_cancel({:error, {:missing_config, [:repo]}})

    {:ok, socket} = RunLive.mount(%{}, %{}, %Socket{})
    {:noreply, socket} = RunLive.handle_params(%{"id" => "run-1"}, "/sonar/runs/run-1", socket)
    {:noreply, socket} = RunLive.handle_event("cancel", %{"run-id" => "run-1"}, socket)

    html =
      socket.assigns
      |> RunLive.render()
      |> rendered_to_string()

    assert html =~ "Failed to cancel run."
    refute html =~ "missing_config"
  end

  test "renders the new run after replay succeeds" do
    source_snapshot =
      snapshot(:completed,
        run_id: "run-1",
        workflow: Atom.to_string(CheckoutWorkflow),
        current_step: "send_receipt",
        reason: :terminal
      )

    replayed_snapshot =
      snapshot(:running,
        run_id: "run-2",
        workflow: Atom.to_string(CheckoutWorkflow),
        current_step: "load_order",
        reason: :attempt_visible
      )

    graph =
      graph_inspection(:completed,
        run_id: "run-1",
        workflow: Atom.to_string(CheckoutWorkflow),
        current_node_id: "send_receipt",
        nodes: [
          graph_node("send_receipt", :completed, true)
        ]
      )

    explanation =
      diagnostic(
        :completed,
        run_id: "run-1",
        workflow: Atom.to_string(CheckoutWorkflow),
        reason: :terminal,
        step: "send_receipt",
        next_actions: [:inspect_terminal_run]
      )

    FakeSquidMeshClient.put_inspect_run(fn
      "run-1", _opts -> {:ok, source_snapshot}
      "run-2", _opts -> {:ok, replayed_snapshot}
    end)

    FakeSquidMeshClient.put_inspect_run_graph(fn
      "run-1", _opts ->
        {:ok, graph}

      "run-2", _opts ->
        {:ok,
         graph_inspection(:running,
           run_id: "run-2",
           workflow: Atom.to_string(CheckoutWorkflow),
           current_node_id: "load_order",
           nodes: [
             graph_node("load_order", :running, true)
           ]
         )}
    end)

    FakeSquidMeshClient.put_explain_run(fn
      "run-1", _opts ->
        {:ok, explanation}

      "run-2", _opts ->
        {:ok,
         diagnostic(:running,
           run_id: "run-2",
           workflow: Atom.to_string(CheckoutWorkflow),
           reason: :attempt_visible,
           step: "load_order",
           next_actions: [:wait_for_worker_claim]
         )}
    end)

    {:ok, socket} = RunLive.mount(%{}, %{}, %Socket{})
    {:noreply, socket} = RunLive.handle_params(%{"id" => "run-1"}, "/sonar/runs/run-1", socket)

    FakeSquidMeshClient.put_replay({:ok, replayed_snapshot})

    {:noreply, socket} = RunLive.handle_event("replay", %{"run-id" => "run-1"}, socket)

    assert socket.assigns.detail.summary.id == "run-2"
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

  test "switches the workflow panel to raw graph inspection" do
    graph =
      graph_inspection(:running,
        run_id: "run-raw-graph",
        workflow: Atom.to_string(CheckoutWorkflow),
        current_node_id: "capture_payment",
        anomalies: [%{kind: :missing_recovery_metadata}],
        nodes: [
          graph_node("capture_payment", :running, true,
            recovery: %{
              compensation: %{callback: "ReleaseInventory", status: :available},
              failure: %{strategy: :compensation, target: "release_inventory"}
            }
          )
        ],
        edges: [
          graph_edge("capture_payment", "release_inventory", :error, recovery: :compensation)
        ]
      )

    snapshot =
      snapshot(:running,
        run_id: "run-raw-graph",
        workflow: Atom.to_string(CheckoutWorkflow),
        current_step: "capture_payment",
        reason: :attempt_visible
      )

    explanation =
      diagnostic(
        :running,
        run_id: "run-raw-graph",
        workflow: Atom.to_string(CheckoutWorkflow),
        reason: :attempt_visible,
        step: "capture_payment",
        next_actions: [:wait_for_worker_claim]
      )

    FakeSquidMeshClient.put_inspect_run({:ok, snapshot})
    FakeSquidMeshClient.put_inspect_run_graph({:ok, graph})
    FakeSquidMeshClient.put_explain_run({:ok, explanation})

    {:ok, socket} = RunLive.mount(%{}, %{}, %Socket{})

    {:noreply, socket} =
      RunLive.handle_params(%{"id" => "run-raw-graph"}, "/sonar/runs/run-raw-graph", socket)

    visual_html =
      socket.assigns
      |> RunLive.render()
      |> rendered_to_string()

    assert visual_html =~ "Transition graph"
    assert visual_html =~ "Raw inspection"
    assert visual_html =~ "Rollback"
    assert visual_html =~ "ReleaseInventory"
    assert visual_html =~ "available"
    refute visual_html =~ ~s("current_node_ids")

    {:noreply, socket} =
      RunLive.handle_event("select_workflow_panel", %{"view" => "raw"}, socket)

    raw_html =
      socket.assigns
      |> RunLive.render()
      |> rendered_to_string()

    assert raw_html =~ "Raw graph inspection"
    assert raw_html =~ "&quot;current_node_ids&quot;"
    assert raw_html =~ "&quot;nodes&quot;"
    assert raw_html =~ "&quot;edges&quot;"
    assert raw_html =~ "&quot;recovery&quot;"
    assert raw_html =~ "&quot;anomalies&quot;"
    assert raw_html =~ "missing_recovery_metadata"
    assert raw_html =~ "ReleaseInventory"
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
