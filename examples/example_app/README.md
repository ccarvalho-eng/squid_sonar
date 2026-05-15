# SquidSonar Example App

This Phoenix app demonstrates SquidSonar mounted inside a real host
application. It installs Squid Mesh, defines a small set of workflow examples,
and exposes the embedded dashboard at `/sonar`.

Use it to try SquidSonar locally with realistic runtime data.

## Run Locally

```bash
mix deps.get
mix ecto.create
mix ecto.migrate
mix example.seed
mix phx.server
```

Open `http://localhost:4010/sonar`.

## Included Workflow Runs

The seed task creates several Squid Mesh runs so the dashboard has useful data
immediately:

- Completed checkout
- Failed checkout
- Retrying checkout
- Manual review checkout paused for approval

Each run can be opened from the dashboard to inspect status, current step,
diagnosis, attempt history, history counts, last error metadata, and the
workflow graph.

## Verification

Run the example app test suite with:

```bash
mix precommit
```
