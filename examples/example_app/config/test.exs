import Config

config :squid_sonar_example, SquidSonarExample.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "squid_sonar_example_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :squid_sonar_example, SquidSonarExampleWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4011],
  secret_key_base: "squid_sonar_example_test_secret_key_base_at_least_sixty_four_bytes_long",
  server: false

config :squid_sonar_example, :journal_run, enabled: false

config :logger, level: :warning
