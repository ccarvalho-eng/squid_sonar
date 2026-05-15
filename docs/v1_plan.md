# SquidSonar v1 Plan

## Product Boundary

SquidSonar is a private embeddable companion UI for Squid Mesh. It is an
operator surface, not a workflow engine. It must not define, schedule, or
execute workflows. The first version should mount inside a host Phoenix
application and make existing Squid Mesh runs easier to inspect, explain, and
eventually operate.

## Design Reference

Use Aludel as the primary design reference for:

- dense dashboard layout
- compact cards and tables
- quiet dark/light theme tokens
- status badges
- run detail pages with structured metadata panels
- small chart and copy/export interactions

Do not carry over Aludel's domain model, daisyUI dependency, provider branding,
or eval-specific navigation.

## V1 Stop Line

V1 is done when a host Phoenix app can mount Sonar and inspect Squid Mesh runs
without Sonar owning persistence, runtime execution, endpoint supervision, or
application deployment.

Required v1 behavior:

- embeddable Phoenix router macro, for example
  `squid_sonar "/sonar", otp_app: :my_app`
- documented LiveView route fallback for hosts that prefer explicit routes
- run index with status filters and recent runs
- run detail page
- step/run history display when available
- explanation panel powered by `SquidMesh.explain_run/2`
- read-only graph or ordered step-state visualization
- test coverage against fake/public Squid Mesh data
- example integration against Squid Mesh's minimal host app or a temporary host

Explicitly out of v1:

- standalone server as the primary distribution shape
- editing workflow definitions
- starting arbitrary runs from the UI
- secrets management
- Python DAG support
- independent scheduler/executor
- replacing LiveDashboard or Oban Web

## Implementation Slices

### Slice 1: Project Scaffold

- Create a Phoenix-compatible embeddable library structure.
- Configure Mix, formatting, ExUnit, assets, and CI-ready commands.
- Add a minimal README that states the private/internal status and mount goal.
- Keep dependencies narrow: Phoenix LiveView, Phoenix HTML, Ecto where needed,
  and Squid Mesh as a path dependency during development.

Verification:

- `mix deps.get`
- `mix format --check-formatted`
- `mix compile --warnings-as-errors`
- `mix test`

### Slice 2: Data Boundary

- Add `SquidSonar.Runs` as the only boundary that calls Squid Mesh.
- Support listing runs via `SquidMesh.list_runs/2`.
- Support inspecting one run via `SquidMesh.inspect_run/2` with history.
- Support explaining one run via `SquidMesh.explain_run/2`.
- Normalize data into Sonar view structs so LiveViews do not depend on raw
  Squid Mesh structs everywhere.

Verification:

- Unit tests with fake adapters or public Squid Mesh test data.
- Regression tests for missing config, not found, invalid run id, and empty
  history.

### Slice 3: Run Index UI

- Build a mountable LiveView for recent runs.
- Include status summary counts, status filters, workflow/trigger labels, and
  updated timestamp.
- Use Aludel-inspired dense cards/table layout, but with Sonar naming and
  workflow operations language.

Verification:

- LiveView tests for filtering, empty state, and row links.
- Manual visual smoke in a host app.

### Slice 4: Run Detail UI

- Show run identity, status, workflow, trigger, current step, timestamps, and
  replay lineage.
- Show explanation reason, evidence summary, and valid next actions as read-only
  operator guidance.
- Show step runs, attempts, errors, and audit events when history is present.

Verification:

- LiveView tests for completed, failed, retrying, paused, and cancelled runs.
- Regression tests for runs with missing/unavailable workflow modules.

### Slice 5: Graph Visualization

- Add a read-only graph or structured step map from persisted step state.
- Prefer a simple accessible layout first: ordered lanes, dependency groups, or
  Mermaid export if direct graph rendering becomes too much for v1.
- Do not block v1 on a complex canvas library.

Verification:

- Tests prove every persisted step status maps to a visual status.
- Manual responsive checks for desktop and narrow widths.

### Slice 6: Host Integration

- Provide a route macro or clear installation docs.
- Integrate into Squid Mesh's minimal host app or a temporary Phoenix host app.
- Run smoke tests against real Squid Mesh persistence and runtime paths.
- Ensure Sonar does not require owning the host endpoint, repo, supervision tree,
  authentication system, or deployment topology.

Verification:

- Host app boots with Sonar mounted.
- Smoke creates or loads runs and renders index/detail pages.

### Slice 7: Optional Guarded Operations

Only after read-only v1 is solid:

- cancel run
- approve run
- reject run
- unblock run
- replay run with explicit irreversible warning

These must use Squid Mesh public APIs, show confirmation, handle stale state,
and include audit/terminal-state review before merge.

## Review Gates

Before considering v1 complete:

- architecture boundary review: Sonar remains UI/control-plane only
- correctness review: no stale reads before unsafe mutations
- security review: no secrets or payload leakage assumptions
- maintainability review: LiveViews remain thin and data shaping stays in the
  boundary modules
- full format, compile, test, and host smoke verification
