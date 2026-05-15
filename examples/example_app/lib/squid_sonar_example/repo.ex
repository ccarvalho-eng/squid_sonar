defmodule SquidSonarExample.Repo do
  use Ecto.Repo,
    otp_app: :squid_sonar_example,
    adapter: Ecto.Adapters.Postgres
end
