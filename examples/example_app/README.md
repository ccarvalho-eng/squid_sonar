# SquidSonar Example App

This Phoenix app is the QA and demo harness for SquidSonar.

It mounts the embeddable UI at `/sonar` and will grow a set of real Squid Mesh
workflow scenarios as each product feature lands.

```bash
mix deps.get
mix ecto.create
mix ecto.migrate
mix example.seed
mix precommit
mix phx.server
```

Visit `/sonar` to inspect the embedded UI.

The seed task starts real Squid Mesh workflows that cover completed, failed,
retrying, and paused manual-review runs.
