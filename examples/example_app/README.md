# SquidSonar Example App

This Phoenix app is the QA and demo harness for SquidSonar.

It mounts the embeddable UI at `/sonar` and will grow a set of real Squid Mesh
workflow scenarios as each product feature lands.

```bash
mix deps.get
mix precommit
mix phx.server
```

Visit `/sonar` to inspect the embedded UI.
