defmodule SquidSonarWeb.WorkflowGraphLayoutTest do
  use ExUnit.Case, async: true

  alias SquidSonar.Runs.WorkflowGraph
  alias SquidSonarWeb.WorkflowGraphLayout

  test "uses the computed height for nodes with compensation callbacks" do
    layout =
      WorkflowGraphLayout.build(%WorkflowGraph{
        nodes: [
          %WorkflowGraph.Node{
            name: "capture_payment",
            label: "Capture payment",
            status: :failed,
            recovery: %{
              compensation: %{
                callback: SquidSonar.TestSupport.Workflows.ReleaseInventory,
                status: :available
              }
            }
          }
        ],
        edges: []
      })

    assert [%{height: 112}] = layout.nodes
  end

  test "uses the standard track height when compensation callback is absent" do
    layout =
      WorkflowGraphLayout.build(%WorkflowGraph{
        nodes: [
          %WorkflowGraph.Node{
            name: "capture_payment",
            label: "Capture payment",
            status: :failed,
            recovery: %{
              compensation: %{
                status: :available
              }
            }
          }
        ],
        edges: []
      })

    assert [%{height: 58}] = layout.nodes
    assert layout.height == 98
  end
end
