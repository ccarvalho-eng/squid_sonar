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

  alias SquidMesh.Run
  alias SquidMesh.RunExplanation
  alias SquidMesh.RunStepState
  alias SquidMesh.StepAttempt
  alias SquidMesh.StepRun
  alias SquidSonar.FakeSquidMeshClient
  alias SquidSonar.Runs
  alias SquidSonar.Runs.RunDetail
  alias SquidSonar.Runs.RunSummary

  @client FakeSquidMeshClient

  test "lists run summaries through the configured client" do
    run = %Run{
      id: "run-1",
      workflow: ExampleWorkflow,
      trigger: :manual,
      status: :running,
      current_step: :charge_card,
      inserted_at: ~U[2026-05-15 10:00:00Z],
      updated_at: ~U[2026-05-15 10:01:00Z]
    }

    FakeSquidMeshClient.put_list_runs({:ok, [run]})

    assert {:ok, [%RunSummary{} = summary]} =
             Runs.list_runs([status: :running], client: @client)

    assert summary.id == "run-1"
    assert summary.workflow == ExampleWorkflow
    assert summary.trigger == :manual
    assert summary.status == :running
    assert summary.current_step == :charge_card
  end

  test "returns client list errors unchanged" do
    FakeSquidMeshClient.put_list_runs({:error, {:missing_config, [:repo]}})

    assert {:error, {:missing_config, [:repo]}} =
             Runs.list_runs([], client: @client)
  end

  test "gets run detail with history and explanation" do
    run = %Run{
      id: "run-2",
      workflow: ExampleWorkflow,
      trigger: :manual,
      status: :failed,
      payload: %{"order_id" => "order-1"},
      context: %{"attempted" => true},
      current_step: :capture_payment,
      last_error: %{"message" => "gateway unavailable"},
      step_runs: [
        %StepRun{
          id: "step-run-1",
          step: :capture_payment,
          status: :failed,
          attempts: [
            %StepAttempt{
              attempt_number: 1,
              status: :failed,
              error: %{"message" => "gateway unavailable"},
              inserted_at: ~U[2026-05-15 10:00:01Z],
              updated_at: ~U[2026-05-15 10:00:02Z]
            }
          ]
        }
      ],
      audit_events: []
    }

    explanation = %RunExplanation{
      status: :failed,
      reason: :step_failed,
      step: :capture_payment,
      next_actions: [:replay_run],
      evidence: %{
        step_states: [
          %RunStepState{step: :capture_payment, status: :failed}
        ]
      }
    }

    FakeSquidMeshClient.put_inspect_run({:ok, run})
    FakeSquidMeshClient.put_explain_run({:ok, explanation})

    assert {:ok, %RunDetail{} = detail} = Runs.get_run("run-2", client: @client)
    assert detail.summary.id == "run-2"
    assert detail.payload == %{"order_id" => "order-1"}
    assert detail.last_error == %{"message" => "gateway unavailable"}
    assert [%StepRun{step: :capture_payment}] = detail.step_runs

    assert [
             %{
               step: :capture_payment,
               attempt_number: 1,
               status: :failed,
               error: %{"message" => "gateway unavailable"}
             }
           ] = detail.step_attempts

    assert detail.explanation.reason == :step_failed
  end

  test "projects the declared workflow graph with the stopped step marked" do
    run = %Run{
      id: "run-4",
      workflow: CheckoutWorkflow,
      trigger: :manual,
      status: :failed,
      current_step: :capture_payment,
      steps: [
        %RunStepState{step: :load_order, status: :completed},
        %RunStepState{step: :capture_payment, status: :failed}
      ],
      step_runs: [
        %StepRun{id: "step-run-1", step: :load_order, status: :completed},
        %StepRun{id: "step-run-2", step: :capture_payment, status: :failed}
      ],
      audit_events: []
    }

    explanation = %RunExplanation{
      status: :failed,
      reason: :step_failed,
      step: :capture_payment,
      next_actions: [:replay_run],
      evidence: %{step_states: List.wrap(run.steps)}
    }

    FakeSquidMeshClient.put_inspect_run({:ok, run})
    FakeSquidMeshClient.put_explain_run({:ok, explanation})

    assert {:ok, %RunDetail{} = detail} = Runs.get_run("run-4", client: @client)

    assert Enum.map(detail.workflow_graph.nodes, & &1.name) == [
             :load_order,
             :capture_payment,
             :send_receipt,
             :complete
           ]

    assert Enum.map(detail.workflow_graph.edges, &{&1.from, &1.to, &1.outcome}) == [
             {:load_order, :capture_payment, :ok},
             {:capture_payment, :send_receipt, :ok},
             {:send_receipt, :complete, :ok}
           ]

    assert %{status: :completed, current?: false} =
             Enum.find(detail.workflow_graph.nodes, &(&1.name == :load_order))

    assert %{status: :failed, current?: true} =
             Enum.find(detail.workflow_graph.nodes, &(&1.name == :capture_payment))

    assert %{status: :waiting, current?: false} =
             Enum.find(detail.workflow_graph.nodes, &(&1.name == :send_receipt))
  end

  test "projects current run statuses without passing them into workflow inspection" do
    for status <- [:paused, :retrying] do
      run = %Run{
        id: "run-#{status}",
        workflow: CheckoutWorkflow,
        trigger: :manual,
        status: status,
        current_step: :capture_payment,
        steps: [
          %RunStepState{step: :load_order, status: :completed},
          %RunStepState{step: :capture_payment, status: :running}
        ],
        step_runs: [
          %StepRun{id: "step-run-#{status}-1", step: :load_order, status: :completed},
          %StepRun{id: "step-run-#{status}-2", step: :capture_payment, status: :running}
        ],
        audit_events: []
      }

      explanation = %RunExplanation{
        status: status,
        reason: :step_running,
        step: :capture_payment,
        next_actions: [],
        evidence: %{step_states: List.wrap(run.steps)}
      }

      FakeSquidMeshClient.put_inspect_run({:ok, run})
      FakeSquidMeshClient.put_explain_run({:ok, explanation})

      assert {:ok, %RunDetail{} = detail} = Runs.get_run(run.id, client: @client)

      assert %{status: ^status, current?: true} =
               Enum.find(detail.workflow_graph.nodes, &(&1.name == :capture_payment))
    end
  end

  test "returns inspect errors before explaining the run" do
    FakeSquidMeshClient.put_inspect_run({:error, :invalid_run_id})

    assert {:error, :invalid_run_id} = Runs.get_run("bad", client: @client)
  end

  test "returns explanation errors unchanged" do
    FakeSquidMeshClient.put_inspect_run({:ok, %Run{id: "run-3"}})
    FakeSquidMeshClient.put_explain_run({:error, :not_found})

    assert {:error, :not_found} = Runs.get_run("run-3", client: @client)
  end
end
