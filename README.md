<div align="center">
  <img width="350" alt="SquidSonar logo" src="https://github.com/user-attachments/assets/29191586-edda-449c-8d97-ea8e47bc4936" />

  **A polished, embeddable runtime dashboard for Squid Mesh.**

  <p>
    <a href="https://github.com/ccarvalho-eng/squid_sonar/actions/workflows/ci.yml"><img src="https://github.com/ccarvalho-eng/squid_sonar/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
    <a href="https://github.com/ccarvalho-eng/squid_sonar/blob/main/LICENSE"><img src="https://img.shields.io/github/license/ccarvalho-eng/squid_sonar" alt="License"></a>
  </p>
</div>

SquidSonar adds a read-only Phoenix LiveView dashboard to applications that run
Squid Mesh workflows. Mount it inside an existing Phoenix app to inspect recent
runs, filter by status, search runtime metadata, and open detail pages that show
the workflow graph, diagnosis, history counts, and last error information.

## Current Shape

SquidSonar is distributed as an embeddable library, not a standalone service. A
host Phoenix application owns authentication, authorization, deployment,
endpoint configuration, and the Squid Mesh runtime. SquidSonar contributes the
router macro, LiveViews, static assets, and a small read boundary over Squid
Mesh public APIs.

The current UI includes:

- Recent workflow runs sorted by update time
- Status counts and filters
- Search across workflow, trigger, step, status, and run ID
- Page size controls and pagination
- Run detail pages with diagnosis, history counts, last error, and workflow
  graph visualization
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
    {:squid_sonar, github: "ccarvalho-eng/squid_sonar"}
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

    squid_sonar "/sonar", otp_app: :my_app
  end
end
```

Visit `/ops/sonar` to open the dashboard.

SquidSonar accepts a few route-level options:

```elixir
squid_sonar "/sonar",
  otp_app: :my_app,
  as: :runtime_sonar,
  socket_path: "/live",
  transport: "websocket"
```

`transport` can be `"websocket"` or `"longpoll"`.

## Security

SquidSonar intentionally does not ship its own authentication layer. Protect the
mounted route with the same browser pipeline, session handling, and
authorization rules used for the rest of the host application's operator
surface.

The current dashboard is read-only. It displays runtime data returned by Squid
Mesh, including workflow names, run IDs, step names, statuses, diagnostic
signals, and selected error metadata. Treat the mounted dashboard as operational
visibility and expose it only to trusted users.

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

Open `http://localhost:4010/sonar` after the server starts.

## Library Modules

- `SquidSonar.Router` mounts the embedded dashboard routes.
- `SquidSonar.Runs` is the read boundary over Squid Mesh run APIs.
- `SquidSonar.Dashboard` builds the filtered, paginated dashboard snapshot.
- `SquidSonar.Runs.WorkflowGraph` turns workflow definitions and persisted run
  state into a display graph.
- `SquidSonarWeb.*` contains the embedded LiveViews, components, layout, hooks,
  and asset controller.

## License

Apache-2.0
