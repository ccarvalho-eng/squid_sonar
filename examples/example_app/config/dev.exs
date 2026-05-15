import Config

config :squid_sonar_example, SquidSonarExample.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "squid_sonar_example_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :squid_sonar_example, SquidSonarExampleWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4010],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "squid_sonar_example_dev_secret_key_base_at_least_sixty_four_bytes_long"

config :logger, :console, format: "[$level] $message\n"
