defmodule SquidSonar.RunsTest do
  use ExUnit.Case, async: true

  alias SquidMesh.Run
  alias SquidMesh.RunExplanation
  alias SquidMesh.RunStepState
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
        %StepRun{id: "step-run-1", step: :capture_payment, status: :failed}
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
    assert detail.explanation.reason == :step_failed
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
