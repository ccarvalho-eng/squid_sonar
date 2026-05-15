# SquidSonar

<p>
  <a href="https://github.com/ccarvalho-eng/squid_sonar/actions/workflows/ci.yml"><img src="https://github.com/ccarvalho-eng/squid_sonar/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://hex.pm/packages/squid_sonar"><img src="https://img.shields.io/hexpm/v/squid_sonar.svg" alt="Hex.pm"></a>
  <a href="https://hexdocs.pm/squid_sonar"><img src="https://img.shields.io/badge/docs-hexdocs-blue" alt="HexDocs"></a>
  <a href="https://github.com/ccarvalho-eng/squid_sonar/blob/main/LICENSE"><img src="https://img.shields.io/github/license/ccarvalho-eng/squid_sonar" alt="License"></a>
</p>

Embeddable runtime UI for Squid Mesh.

SquidSonar is intended to mount inside a Phoenix host application, similar in
spirit to Oban Web, but focused on Squid Mesh workflow runs.

```elixir
def deps do
  [
    {:squid_sonar, github: "ccarvalho-eng/squid_sonar"}
  ]
end
```

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  use SquidSonar.Router

  scope "/dev" do
    pipe_through :browser

    squid_sonar "/sonar", otp_app: :my_app
  end
end
```

The first production goal is a read-only embedded UI for inspecting runs,
steps, attempts, audit events, and `SquidMesh.explain_run/2` output.

This repo will also include an example app for demos and QA smoke tests. That
app can run standalone, but it is a harness, not the primary deployment shape.

## License

Apache-2.0
