defmodule SquidSonarExampleWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :squid_sonar_example

  @session_options [
    store: :cookie,
    key: "_squid_sonar_example_key",
    signing_salt: "squid-sonar-example"
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: [connect_info: [session: @session_options]]

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug SquidSonarExampleWeb.Router
end
