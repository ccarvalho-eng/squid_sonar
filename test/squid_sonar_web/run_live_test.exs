defmodule SquidSonarWeb.RunLiveTest do
  use ExUnit.Case, async: false

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
  alias SquidMesh.ReadModel.Explanation.Diagnostic
  alias SquidMesh.ReadModel.Inspection.Snapshot
  alias SquidMesh.Runs.GraphInspection
  alias SquidMesh.Runs.GraphInspection.Edge
  alias SquidMesh.Runs.GraphInspection.Node
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

  defp snapshot(status, attrs) do
    workflow = Keyword.fetch!(attrs, :workflow)

    %Snapshot{
      run_id: Keyword.get(attrs, :run_id, "run-#{status}"),
      workflow: workflow,
      trigger: "manual",
      input: %{"order_id" => "order-1"},
      context: %{"attempted" => true},
      queue: "default",
      status: status,
      reason: Keyword.get(attrs, :reason, :attempt_visible),
      terminal?: Keyword.get(attrs, :terminal?, status in [:completed, :failed, :cancelled]),
      terminal_status:
        Keyword.get(attrs, :terminal_status, if(status == :completed, do: :completed, else: nil)),
      thread_revisions: %{run: 3, dispatch: 4},
      planned_runnables: Keyword.get(attrs, :planned_runnables, []),
      planned_runnable_keys: [],
      applied_runnable_keys: [],
      pending_dispatches: [],
      pending_results: [],
      visible_attempts: [],
      scheduled_attempts: [],
      next_visible_at: nil,
      expired_claims: [],
      attempts: Keyword.get(attrs, :attempts, []),
      anomalies: Keyword.get(attrs, :anomalies, [])
    }
  end

  defp diagnostic(status, attrs) do
    workflow = Keyword.fetch!(attrs, :workflow)

    %Diagnostic{
      run_id: Keyword.get(attrs, :run_id, "run-#{status}"),
      workflow: workflow,
      queue: "default",
      status: status,
      reason: Keyword.get(attrs, :reason, :attempt_visible),
      step: Keyword.get(attrs, :step),
      summary: Keyword.get(attrs, :summary, "summary"),
      details: Keyword.get(attrs, :details, %{}),
      next_actions: Keyword.get(attrs, :next_actions, []),
      evidence: Keyword.get(attrs, :evidence, %{})
    }
  end

  defp graph_inspection(status, attrs) do
    workflow = Keyword.fetch!(attrs, :workflow)

    %GraphInspection{
      run_id: Keyword.get(attrs, :run_id, "run-#{status}"),
      workflow: workflow,
      source: :read_model,
      status: status,
      current_node_id: Keyword.get(attrs, :current_node_id),
      current_node_ids: List.wrap(Keyword.get(attrs, :current_node_id)),
      terminal?: Keyword.get(attrs, :terminal?, status in [:completed, :failed, :cancelled]),
      nodes: Keyword.get(attrs, :nodes, []),
      edges: Keyword.get(attrs, :edges, []),
      anomalies: []
    }
  end

  defp graph_node(id, status, current?) do
    %Node{
      id: id,
      status: status,
      current?: current?,
      input: nil,
      output: nil,
      error: nil,
      recovery: nil,
      transition: nil,
      manual_state: nil,
      attempts: []
    }
  end

  defp graph_edge(from, to, outcome) do
    %Edge{
      id: "#{from}:#{outcome}:#{to}",
      from: from,
      to: to,
      type: edge_type(outcome),
      status: :pending,
      outcome: outcome,
      condition: nil,
      recovery: nil
    }
  end

  defp edge_type(:ready), do: :dependency
  defp edge_type(_outcome), do: :transition

  defp attempt(step, status, attempt_number, error) do
    %{
      step: step,
      status: status,
      attempt_number: attempt_number,
      error: error
    }
  end
end
