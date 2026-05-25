defmodule Mix.Tasks.Example.SeedTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  setup_all do
    Mix.Task.run("app.start")
    ensure_journal_schema!()
    :ok
  end

  test "drains seeded runs far enough to show representative statuses" do
    output =
      capture_io(fn ->
        Mix.Tasks.Example.Seed.run([])
      end)

    assert output =~ "Seeded Squid Mesh example runs."
    assert output =~ "completed"
    assert output =~ "failed"
    assert output =~ "retrying"
    assert output =~ "paused"
  end

  defp ensure_journal_schema! do
    repo = SquidSonarExample.Repo

    repo.query!("""
    CREATE TABLE IF NOT EXISTS squid_mesh_journal_threads (
      id text PRIMARY KEY,
      rev bigint NOT NULL DEFAULT 0,
      metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
      created_at_ms bigint NOT NULL,
      updated_at_ms bigint NOT NULL,
      inserted_at timestamp(6) without time zone NOT NULL,
      updated_at timestamp(6) without time zone NOT NULL
    )
    """)

    repo.query!("""
    CREATE TABLE IF NOT EXISTS squid_mesh_journal_entries (
      id uuid PRIMARY KEY,
      thread_id text NOT NULL REFERENCES squid_mesh_journal_threads(id) ON DELETE CASCADE,
      seq bigint NOT NULL,
      entry bytea NOT NULL,
      inserted_at timestamp(6) without time zone NOT NULL,
      updated_at timestamp(6) without time zone NOT NULL
    )
    """)

    repo.query!("""
    CREATE UNIQUE INDEX IF NOT EXISTS squid_mesh_journal_entries_thread_id_seq_index
    ON squid_mesh_journal_entries (thread_id, seq)
    """)

    repo.query!("""
    CREATE TABLE IF NOT EXISTS squid_mesh_journal_checkpoints (
      key_hash text PRIMARY KEY,
      key bytea NOT NULL,
      checkpoint bytea NOT NULL,
      inserted_at timestamp(6) without time zone NOT NULL,
      updated_at timestamp(6) without time zone NOT NULL
    )
    """)
  end
end
