# Journal-Aware Workflow Graph Design

**Goal:** Make the run detail view reflect the journal-backed Squid Mesh runtime more clearly, with the workflow graph as the primary visual and the run history as supporting evidence.

## Current State

SquidSonar already renders run summaries and a workflow graph for each run. The current run detail page shows:

- run summary fields
- a diagnosis panel with reason, next actions, and last error
- a history panel with step records, attempts, and audit events
- a workflow graph based on `SquidSonar.Runs.WorkflowGraph` and `SquidSonarWeb.WorkflowGraphLayout`

The app already receives enough runtime data to show the graph as a journal-backed view:

- `RunDetail.summary` for the top-level run facts
- `RunDetail.explanation` for reason and next actions
- `RunDetail.workflow_graph` for graph mode, nodes, and edges
- `RunDetail.step_runs`, `RunDetail.step_attempts`, and `RunDetail.audit_events` for journal evidence

No new backend query shape is required for this slice.

## Design

The run detail view should make the journal-backed runtime explicit without changing the page into a different product.

### 1. Graph header becomes journal-aware

The workflow section should gain a compact header above the graph that shows:

- a runtime eyebrow such as `Journal-backed runtime`
- the workflow name
- the trigger
- a graph mode badge derived from `workflow_graph.mode`
- the current run status

The mode badge should distinguish:

- `transition`
- `dependency`
- `history`

That makes the graph read as a runtime projection, not just a static diagram.

### 2. The graph stays the primary visual

The existing graph layout should remain the center of the section. The goal is not to replace it with a timeline or split view.

The nodes should keep the current status styling, but the section should make the following easier to see:

- which node is current
- which node is terminal
- whether the graph is showing transition, dependency, or history mode

The existing graph node and edge layout is enough for this slice.

### 3. History becomes supporting evidence

The lower history panel should be explicitly framed as journal evidence rather than generic history.

It should keep showing:

- step records
- attempts
- audit events

But the labels should make the relationship to the journal-backed runtime clearer. The panel should support scanning for recovery and replay behavior without competing with the graph.

### 4. Diagnosis stays visible

The current diagnosis panel should remain in place. It is useful for explaining why the run is where it is and what actions are available next.

The design should not duplicate the diagnosis text in the graph header. The graph header should stay compact.

## Data Flow

The data flow remains the same:

1. `RunLive` loads a `RunDetail` through `SquidSonar.Runs.get_run/2`.
2. `RunDetail.from_run/2` already combines the summary, graph projection, explanation, history, and attempts.
3. `SquidSonarWeb.CoreComponents.run_detail/1` renders the page from that single projection object.

This slice should prefer presentation-only changes. If the UI needs one small helper to format the graph mode or the runtime eyebrow, that helper should live in the web component layer.

## Files Likely To Change

- `lib/squid_sonar_web/components/core_components.ex`
- `test/squid_sonar_web/run_live_test.exs`
- possibly `test/squid_sonar/runs_test.exs` if the graph presentation needs a new regression for mode-sensitive rendering
- `mix.exs`
- `examples/example_app/mix.exs`
- `mix.lock`

No routing, database, or client API changes are expected.

## Testing Plan

The implementation should be covered with UI-focused regressions:

- the run detail view renders the new journal-aware graph header
- the graph mode badge reflects the current workflow graph mode
- the history section still renders step records, attempts, and audit events
- the page still renders the current run status, explanation, and graph nodes
- the project dependency pins point at the current `squid_mesh` beta release

The strongest regression target is `test/squid_sonar_web/run_live_test.exs`, because it already exercises the full render path from fake client data through the LiveView.

## Non-Goals

- no new graph data model
- no new route or page
- no separate timeline view
- no change to the dashboard list layout
- no change to Squid Mesh client calls

## Risk

The main risk is overloading the detail page with too much secondary information. The graph must remain the first thing the user sees, and the journal evidence must stay compact enough to scan quickly.
