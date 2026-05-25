defmodule SquidSonar.RunsTest do
  use ExUnit.Case, async: true

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

  defmodule DependencyWorkflow do
    use SquidMesh.Workflow

    workflow do
      trigger :manual do
        manual()
      end

      step(:load_account, :log, message: "load account")
      step(:load_invoice, :log, message: "load invoice", after: [:load_account])
      step(:send_email, :log, message: "send email", after: [:load_account, :load_invoice])
    end
  end

  defmodule MissingWorkflow do
  end

  alias SquidMesh.ReadModel.Explanation.Diagnostic
  alias SquidMesh.ReadModel.Inspection.Snapshot
  alias SquidMesh.ReadModel.Listing.Summary
  alias SquidMesh.Runs.GraphInspection
  alias SquidMesh.Runs.GraphInspection.Edge
  alias SquidMesh.Runs.GraphInspection.Node
  alias SquidSonar.FakeSquidMeshClient
  alias SquidSonar.Runs
  alias SquidSonar.Runs.RunDetail
  alias SquidSonar.Runs.RunSummary

  @client FakeSquidMeshClient
  @now ~U[2026-05-15 10:00:00Z]

  test "lists run summaries through the configured client" do
    FakeSquidMeshClient.put_list_runs(
      {:ok,
       [
         summary(:running, workflow: Atom.to_string(CheckoutWorkflow), queue: "default"),
         summary(:failed, workflow: Atom.to_string(DependencyWorkflow), queue: "priority")
       ]}
    )

    assert {:ok, [%RunSummary{} = first, %RunSummary{} = second]} =
             Runs.list_runs([status: :running], client: @client)

    assert first.id == "run-running"
    assert first.workflow == Atom.to_string(CheckoutWorkflow)
    assert first.queue == "default"
    assert first.status == :running

    assert second.id == "run-failed"
    assert second.workflow == Atom.to_string(DependencyWorkflow)
    assert second.queue == "priority"
    assert second.status == :failed
  end

  test "returns client list errors unchanged" do
    FakeSquidMeshClient.put_list_runs({:error, {:missing_config, [:repo]}})

    assert {:error, {:missing_config, [:repo]}} =
             Runs.list_runs([], client: @client)
  end

  test "gets run detail with journal evidence and explanation" do
    snapshot =
      snapshot(:running,
        run_id: "run-2",
        workflow: Atom.to_string(CheckoutWorkflow),
        reason: :attempt_visible,
        current_step: "capture_payment",
        attempts: [
          attempt("capture_payment", :claimed, 1, %{"message" => "gateway unavailable"})
        ],
        planned_runnables: [%{runnable_key: "capture_payment"}],
        anomalies: [%{kind: :stale_projection}]
      )

    graph =
      graph_inspection(:running,
        run_id: "run-2",
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
        run_id: "run-2",
        workflow: Atom.to_string(CheckoutWorkflow),
        reason: :attempt_visible,
        step: "capture_payment",
        summary: "A dispatch attempt is visible and waiting for a worker claim.",
        details: %{visible_attempt_count: 1, runnable_keys: ["capture_payment"]},
        next_actions: [:wait_for_worker_claim],
        evidence: %{attempt_counts: %{claimed: 1}}
      )

    FakeSquidMeshClient.put_inspect_run({:ok, snapshot})
    FakeSquidMeshClient.put_inspect_run_graph({:ok, graph})
    FakeSquidMeshClient.put_explain_run({:ok, explanation})

    assert {:ok, %RunDetail{} = detail} = Runs.get_run("run-2", client: @client)

    assert detail.summary.id == "run-2"
    assert detail.summary.workflow == Atom.to_string(CheckoutWorkflow)
    assert detail.summary.queue == "default"
    assert detail.summary.status == :running
    assert detail.summary.current_step == "capture_payment"
    assert detail.summary.reason == :attempt_visible
    assert detail.summary.thread_revisions == %{run: 3, dispatch: 4}

    assert detail.payload == %{"order_id" => "order-1"}
    assert detail.context == %{"attempted" => true}
    assert detail.last_error == %{"message" => "gateway unavailable"}
    assert detail.planned_runnables == [%{runnable_key: "capture_payment"}]
    assert length(detail.attempts) == 1
    assert length(detail.anomalies) == 1
    assert detail.explanation.summary =~ "waiting for a worker claim"

    assert Enum.map(detail.workflow_graph.nodes, & &1.name) == [
             "load_order",
             "capture_payment",
             "send_receipt"
           ]

    assert Enum.map(detail.workflow_graph.edges, &{&1.from, &1.to, &1.outcome}) == [
             {"load_order", "capture_payment", :ok},
             {"capture_payment", "send_receipt", :ok}
           ]
  end

  test "projects dependency mode from the workflow definition" do
    snapshot =
      snapshot(:running,
        workflow: Atom.to_string(DependencyWorkflow),
        reason: :attempt_visible,
        current_step: "send_email",
        attempts: [attempt("send_email", :claimed, 1, nil)]
      )

    graph =
      graph_inspection(:running,
        workflow: Atom.to_string(DependencyWorkflow),
        current_node_id: "send_email",
        nodes: [
          graph_node("load_account", :completed, false),
          graph_node("load_invoice", :completed, false),
          graph_node("send_email", :running, true)
        ],
        edges: [
          graph_edge("load_account", "load_invoice", :ready),
          graph_edge("load_account", "send_email", :ready),
          graph_edge("load_invoice", "send_email", :ready)
        ]
      )

    explanation =
      diagnostic(
        :running,
        workflow: Atom.to_string(DependencyWorkflow),
        reason: :attempt_visible,
        step: "send_email",
        summary: "A dispatch attempt is visible and waiting for a worker claim.",
        details: %{visible_attempt_count: 1, runnable_keys: ["send_email"]},
        next_actions: [:wait_for_worker_claim],
        evidence: %{attempt_counts: %{claimed: 1}}
      )

    FakeSquidMeshClient.put_inspect_run({:ok, snapshot})
    FakeSquidMeshClient.put_inspect_run_graph({:ok, graph})
    FakeSquidMeshClient.put_explain_run({:ok, explanation})

    assert {:ok, %RunDetail{} = detail} = Runs.get_run("run-dependency", client: @client)

    assert detail.workflow_graph.mode == :dependency

    assert Enum.map(detail.workflow_graph.edges, &{&1.from, &1.to, &1.outcome}) == [
             {"load_account", "load_invoice", :ready},
             {"load_account", "send_email", :ready},
             {"load_invoice", "send_email", :ready}
           ]
  end

  test "renders history graphs when the workflow definition is unavailable" do
    snapshot =
      snapshot(:completed,
        workflow: Atom.to_string(MissingWorkflow),
        reason: :terminal,
        current_step: "capture_payment",
        attempts: [
          attempt("load_order", :completed, 1, nil),
          attempt("capture_payment", :completed, 1, nil)
        ]
      )

    graph =
      graph_inspection(:completed,
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

    assert {:ok, %RunDetail{} = detail} = Runs.get_run("run-history", client: @client)

    assert detail.workflow_graph.mode == :history

    assert Enum.map(detail.workflow_graph.nodes, & &1.name) == [
             "load_order",
             "capture_payment"
           ]
  end

  test "returns inspect errors before explaining the run" do
    FakeSquidMeshClient.put_inspect_run({:error, :invalid_run_id})

    assert {:error, :invalid_run_id} = Runs.get_run("bad", client: @client)
  end

  test "returns explanation errors unchanged" do
    snapshot = snapshot(:running, workflow: CheckoutWorkflow)
    graph = graph_inspection(:running, workflow: CheckoutWorkflow)

    FakeSquidMeshClient.put_inspect_run({:ok, snapshot})
    FakeSquidMeshClient.put_inspect_run_graph({:ok, graph})
    FakeSquidMeshClient.put_explain_run({:error, :not_found})

    assert {:error, :not_found} = Runs.get_run("run-3", client: @client)
  end

  defp summary(status, attrs) do
    workflow = Keyword.fetch!(attrs, :workflow)

    %Summary{
      run_id: "run-#{status}",
      workflow: workflow,
      queue: Keyword.get(attrs, :queue, "default"),
      status: status,
      terminal?: status in [:completed, :failed, :cancelled],
      terminal_status: Keyword.get(attrs, :terminal_status, status),
      indexed_at: @now,
      thread_revision: Keyword.get(attrs, :thread_revision, 7),
      anomalies: Keyword.get(attrs, :anomalies, [])
    }
  end

  defp snapshot(status, attrs) do
    workflow = Keyword.fetch!(attrs, :workflow)

    %Snapshot{
      run_id: Keyword.get(attrs, :run_id, "run-#{status}"),
      workflow: workflow,
      trigger: "manual",
      input: Keyword.get(attrs, :input, %{"order_id" => "order-1"}),
      context: Keyword.get(attrs, :context, %{"attempted" => true}),
      queue: Keyword.get(attrs, :queue, "default"),
      status: status,
      reason: Keyword.get(attrs, :reason, :attempt_visible),
      terminal?: Keyword.get(attrs, :terminal?, status in [:completed, :failed, :cancelled]),
      terminal_status:
        Keyword.get(attrs, :terminal_status, if(status == :completed, do: :completed, else: nil)),
      thread_revisions: Keyword.get(attrs, :thread_revisions, %{run: 3, dispatch: 4}),
      planned_runnables: Keyword.get(attrs, :planned_runnables, []),
      planned_runnable_keys: Keyword.get(attrs, :planned_runnable_keys, []),
      applied_runnable_keys: Keyword.get(attrs, :applied_runnable_keys, []),
      pending_dispatches: Keyword.get(attrs, :pending_dispatches, []),
      pending_results: Keyword.get(attrs, :pending_results, []),
      visible_attempts: Keyword.get(attrs, :visible_attempts, []),
      scheduled_attempts: Keyword.get(attrs, :scheduled_attempts, []),
      next_visible_at: Keyword.get(attrs, :next_visible_at),
      expired_claims: Keyword.get(attrs, :expired_claims, []),
      attempts: Keyword.get(attrs, :attempts, []),
      anomalies: Keyword.get(attrs, :anomalies, [])
    }
  end

  defp diagnostic(status, attrs) do
    workflow = Keyword.fetch!(attrs, :workflow)

    %Diagnostic{
      run_id: Keyword.get(attrs, :run_id, "run-#{status}"),
      workflow: workflow,
      queue: Keyword.get(attrs, :queue, "default"),
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
      anomalies: Keyword.get(attrs, :anomalies, [])
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
