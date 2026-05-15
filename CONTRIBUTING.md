# Contributing

SquidSonar is an embeddable Phoenix UI for inspecting Squid Mesh workflow runs.
Keep changes small, focused, and easy to review.

## Development

Use the toolchain in `.tool-versions`, then run:

```bash
mix deps.get
mix precommit
```

`mix precommit` runs compile, format checks, and tests.

## Feature Rule

Every user-facing feature must include matching example-app coverage in the same
slice. The example app is the QA harness for real Squid Mesh workflows and
should make each feature inspectable in a running Phoenix app.

## Pull Requests

- Use Conventional Commits.
- Keep one coherent intent per PR.
- Include the exact verification commands you ran.
- Include screenshots or video for UI changes when practical.
- Do not include secrets, local paths, hostnames, or machine-specific metadata.

