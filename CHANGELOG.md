# Changelog

All notable changes to SquidSonar will be documented in this file.

## 0.1.5 - 2026-05-24

- Added the journal-aware workflow graph header status and shared read-model
  fixtures from the SquidSonar review pass.
- Kept the example seed output focused on completed, failed, retrying, and
  paused runs.
- Removed stale lockfile entries so dependency checks stay green.

## 0.1.4 - 2026-05-24

- Aligned the example app seed with the journal-backed runtime so the seeded
  demo shows completed, failed, retrying, and paused runs.
- Kept the release focused on the journal runtime contract and example
  coverage.

## 0.1.3 - 2026-05-16

- Refined status badge styling with rectangular labels.
- Aligned status filter hover and focus states with the runs table interaction.
- Removed the redundant matching-run summary from the status filter sidebar.

## 0.1.2 - 2026-05-16

- Refined the embedded dashboard with a cleaner, flatter visual system.
- Added a responsive filter menu for smaller screens.
- Improved status filter active states, table controls, run detail surfaces, and
  workflow canvas contrast.

## 0.1.1 - 2026-05-15

- Added visible refresh feedback while dashboard runs reload.

## 0.1.0 - 2026-05-15

- Added the embeddable Phoenix LiveView dashboard for Squid Mesh runs.
- Added status filters, search, pagination, run detail pages, workflow graph
  visualization, attempt counts, and light/dark/system themes.
- Added a Phoenix example app with real Squid Mesh workflow scenarios.
- Added public-facing repository documentation, templates, license, and CI
  metadata.
