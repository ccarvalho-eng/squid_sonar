defmodule SquidSonar.RouterTest do
  use ExUnit.Case, async: true

  defmodule HostRouter do
    use Phoenix.Router
    use SquidSonar.Router

    scope "/" do
      squid_sonar("/sonar")
    end
  end

  test "exports a router macro for embeddable mounting" do
    assert {:squid_sonar, 1} in SquidSonar.Router.__info__(:macros)
    assert {:squid_sonar, 2} in SquidSonar.Router.__info__(:macros)
  end

  test "mounts routes in a host Phoenix router" do
    routes = Phoenix.Router.routes(HostRouter)

    assert Enum.any?(
             routes,
             &(&1.path == "/sonar/css-:digest" and &1.plug == SquidSonarWeb.Assets)
           )

    assert Enum.any?(routes, &(&1.path == "/sonar" and &1.plug == Phoenix.LiveView.Plug))
  end

  test "builds embeddable live session options" do
    assert {:squid_sonar, session_opts, [as: :squid_sonar]} =
             SquidSonar.Router.__options__("/dev/sonar", [])

    assert session_opts[:on_mount] == [SquidSonarWeb.Hooks]
    assert session_opts[:root_layout] == {SquidSonarWeb.Layouts, :root}

    assert {:session, {SquidSonar.Router, :__session__, session_args}} =
             List.keyfind(session_opts, :session, 0)

    assert session_args == ["/dev/sonar", "/live", "websocket"]
  end

  test "supports custom route name and live transport settings" do
    assert {:ops_sonar, session_opts, [as: :ops_sonar]} =
             SquidSonar.Router.__options__(
               "/ops/sonar",
               as: :ops_sonar,
               socket_path: "/custom/live",
               transport: "longpoll"
             )

    assert {:session, {SquidSonar.Router, :__session__, session_args}} =
             List.keyfind(session_opts, :session, 0)

    assert session_args == ["/ops/sonar", "/custom/live", "longpoll"]
  end

  test "rejects invalid transport" do
    assert_raise ArgumentError, ~r/invalid :transport/, fn ->
      SquidSonar.Router.__options__("/sonar", transport: "invalid")
    end
  end

  test "builds live session payload" do
    assert %{
             "prefix" => "/sonar",
             "live_path" => "/live",
             "live_transport" => "websocket"
           } = SquidSonar.Router.__session__(%{}, "/sonar", "/live", "websocket")
  end
end
