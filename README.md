<div align="center">

# SquidSonar — Embeddable runtime dashboard for Squid Mesh

  <img width="400" alt="SquidSonar logo" src="https://github.com/user-attachments/assets/29191586-edda-449c-8d97-ea8e47bc4936" />

  <p>
    <a href="https://github.com/dark-trench/squid_sonar/actions/workflows/ci.yml">
      <img alt="CI" src="https://github.com/dark-trench/squid_sonar/actions/workflows/ci.yml/badge.svg" />
    </a>
    <a href="https://hex.pm/packages/squid_sonar">
      <img alt="Hex" src="https://img.shields.io/hexpm/v/squid_sonar" />
    </a>
    <a href="https://hexdocs.pm/squid_sonar">
      <img alt="HexDocs" src="https://img.shields.io/badge/docs-hexdocs-purple" />
    </a>
    <a href="https://github.com/dark-trench/squid_sonar/blob/main/LICENSE">
      <img alt="License: Apache 2.0" src="https://img.shields.io/badge/license-Apache%202.0-blue.svg" />
    </a>
  </p>
</div>

SquidSonar is a read-only Phoenix LiveView dashboard for applications that run
Squid Mesh workflows.

Mount it inside a Phoenix host application to inspect recent runs, filter by
status, search runtime metadata, and open detail pages with the workflow graph,
diagnosis, attempt counts, history counts, and last error information.

<img width="1377" height="593" alt="Screenshot 2026-05-24 at 22 17 34" src="https://github.com/user-attachments/assets/abad53f5-7155-44c6-b7ed-e9388b9e8e1c" />
<img width="1319" height="919" alt="Screenshot 2026-05-24 at 22 17 45" src="https://github.com/user-attachments/assets/f27fdea9-74c9-4683-9c37-3939816d4b1e" />

## Runtime Boundary

SquidSonar is distributed as an embeddable library, not a standalone service. A
host Phoenix application owns authentication, authorization, deployment,
endpoint configuration, and the Squid Mesh runtime. SquidSonar contributes the
router macro, LiveViews, static assets, and a small read boundary over Squid
Mesh public APIs.

SquidSonar interacts with Squid Mesh through:

### Read Operations
- `SquidMesh.list_runs/2`
- `SquidMesh.inspect_run/2`
- `SquidMesh.inspect_run_graph/2`
- `SquidMesh.explain_run/2`

### Control Operations
- `SquidMesh.cancel/2` - Cancel running workflows
- `SquidMesh.resume/3` - Resume paused workflows
- `SquidMesh.approve/3` - Approve manual approval steps
- `SquidMesh.reject/3` - Reject manual approval steps
- `SquidMesh.replay/2` - Replay completed workflows

Host applications still own workers, queue delivery, scheduler
setup, and backend leasing or fencing. When a Squid Mesh host uses Bedrock or
another delivery backend, that adapter remains part of the host application, not
SquidSonar.

```text
Phoenix Host Application
|
+-- Squid Mesh runtime
|   +-- workers
|   +-- scheduler and delivery backend
|   +-- lease or fencing adapter when needed
|
+-- SquidSonar
    +-- router macro
    +-- read-only LiveViews
    +-- embedded assets
    +-- Squid Mesh inspection API client
```

## Dashboard Surface

The UI includes:

- Recent workflow runs sorted by update time
- Status counts and filters
- Search across workflow, trigger, step, status, and run ID
- Page size controls and pagination
- Run detail pages with diagnosis, history counts, last error, and workflow
  graph visualization
- Step attempt counts on run detail pages
- Light, dark, and system theme controls
- Embedded CSS and JavaScript served by the library

## Requirements

- Elixir 1.17 or later
- Phoenix 1.8
- Phoenix LiveView 1.1
- A host application with Squid Mesh installed and configured

## Installation

Add SquidSonar to the host application's dependencies:

```elixir
def deps do
  [
    {:squid_sonar, "~> 0.1.7"}
  ]
end
```

Then fetch dependencies:

```bash
mix deps.get
```

## Mounting

Import `SquidSonar.Router` in the host router and mount the dashboard under the
path that makes sense for the application:

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  use SquidSonar.Router

  scope "/ops" do
    pipe_through [:browser, :require_authenticated_user]

    squid_sonar "/sonar"
  end
end
```

Visit `/ops/sonar` to open the dashboard.

SquidSonar accepts a few route-level options:

```elixir
squid_sonar "/sonar",
  as: :runtime_sonar,
  socket_path: "/live",
  transport: "websocket"
```

`transport` can be `"websocket"` or `"longpoll"`.

## Security

SquidSonar does not ship its own authentication layer. Protect the mounted route
with the same browser pipeline, session handling, and authorization rules used
for the rest of the host application's operator surface.

The dashboard is read-only, but it displays runtime data returned by Squid Mesh,
including workflow names, run IDs, step names, statuses, diagnostic signals, and
selected error metadata. Treat the mounted dashboard as operational visibility
and expose it only to trusted users.

## Example App

The repository includes a Phoenix example app at `examples/example_app`. It
mounts SquidSonar at `/sonar` and seeds real Squid Mesh workflows that produce
completed, failed, retrying, and paused runs.

```bash
cd examples/example_app
mix deps.get
mix ecto.create
mix ecto.migrate
mix example.seed
mix phx.server
```

Open `http://localhost:4000/sonar` after the server starts.

## Library Modules

- `SquidSonar.Router` mounts the embedded dashboard routes.
- `SquidSonar.Runs` is the read boundary over Squid Mesh run APIs.
- `SquidSonar.Dashboard` builds the filtered, paginated dashboard snapshot.
- `SquidSonar.Runs.WorkflowGraph` turns workflow definitions and persisted run
  state into a display graph.
- `SquidSonarWeb.*` contains the embedded LiveViews, components, layout, hooks,
  and asset controller.

## Community

Use the [Squid Mesh Elixir Forum thread](https://elixirforum.com/t/squid-mesh-workflow-automation-runtime-for-elixir-applications/75162)
for public discussion and design context around the runtime and dashboard.

Use [GitHub issues](https://github.com/dark-trench/squid_sonar/issues) for
dashboard bugs, feature requests, and release-tracked work.

For informal runtime and Jido-adjacent chat, use the
[Squid Mesh channel on the Jido Discord](https://discord.com/channels/1323353012235796550/1504122798027571331).

## License

Apache-2.0
