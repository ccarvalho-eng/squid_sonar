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

  import Phoenix.LiveViewTest

  alias Phoenix.LiveView.Socket
  alias SquidMesh.Run
  alias SquidMesh.RunExplanation
  alias SquidMesh.RunStepState
  alias SquidMesh.StepRun
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
    run = %Run{
      id: "run-1",
      workflow: CheckoutWorkflow,
      trigger: :manual,
      status: :failed,
      current_step: :capture_payment,
      inserted_at: ~U[2026-05-15 10:00:00Z],
      updated_at: ~U[2026-05-15 10:01:00Z],
      last_error: %{code: "gateway_unavailable", message: "Gateway unavailable"},
      steps: [
        %RunStepState{step: :load_order, status: :completed},
        %RunStepState{step: :capture_payment, status: :failed}
      ],
      step_runs: [%StepRun{step: :capture_payment, status: :failed}]
    }

    explanation = %RunExplanation{
      status: :failed,
      reason: :step_failed,
      step: :capture_payment,
      next_actions: [:replay_run],
      evidence: %{step_states: [%RunStepState{step: :capture_payment, status: :failed}]}
    }

    FakeSquidMeshClient.put_inspect_run({:ok, run})
    FakeSquidMeshClient.put_explain_run({:ok, explanation})

    {:ok, socket} = RunLive.mount(%{}, %{}, %Socket{})
    {:noreply, socket} = RunLive.handle_params(%{"id" => "run-1"}, "/sonar/runs/run-1", socket)

    html =
      socket.assigns
      |> RunLive.render()
      |> rendered_to_string()

    assert html =~ "SquidSonar"
    assert html =~ "Run detail"
    assert html =~ "CheckoutWorkflow"
    assert html =~ "step_failed"
    assert html =~ "capture_payment"
    assert html =~ "send_receipt"
    assert html =~ "replay_run"
    assert html =~ "squid-sonar-workflow-graph"
    assert html =~ "squid-sonar-workflow-node-failed"
    assert html =~ "squid-sonar-workflow-node-current"
    assert html =~ "<code>"
    assert html =~ "Gateway unavailable"
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
