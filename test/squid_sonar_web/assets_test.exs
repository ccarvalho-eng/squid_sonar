defmodule SquidSonarWeb.AssetsTest do
  use ExUnit.Case, async: true

  test "serves packaged CSS for the current digest" do
    digest = SquidSonarWeb.Assets.digest()

    conn =
      :get
      |> Plug.Test.conn("/sonar/css-#{digest}")
      |> Map.put(:params, %{"digest" => digest})
      |> SquidSonarWeb.Assets.css(%{})

    assert conn.status == 200
    assert Plug.Conn.get_resp_header(conn, "content-type") == ["text/css; charset=utf-8"]
    assert conn.resp_body =~ ".squid-sonar-shell"
    assert conn.resp_body =~ ".squid-sonar-refresh.phx-click-loading"
  end

  test "rejects stale CSS digests" do
    conn =
      :get
      |> Plug.Test.conn("/sonar/css-stale")
      |> Map.put(:params, %{"digest" => "stale"})
      |> SquidSonarWeb.Assets.css(%{})

    assert conn.status == 404
  end

  test "serves packaged JavaScript for the current digest" do
    digest = SquidSonarWeb.Assets.js_digest()

    conn =
      :get
      |> Plug.Test.conn("/sonar/js-#{digest}")
      |> Map.put(:params, %{"digest" => digest})
      |> SquidSonarWeb.Assets.js(%{})

    assert conn.status == 200
    assert Plug.Conn.get_resp_header(conn, "content-type") == ["text/javascript; charset=utf-8"]
    assert conn.resp_body =~ "new LiveSocket"
    assert conn.resp_body =~ "squid-sonar-theme"
    assert conn.resp_body =~ "SquidSonarTheme"
  end

  test "serves packaged LiveView client dependencies" do
    assert_asset_response(:phoenix, "Socket")
    assert_asset_response(:live_view, "LiveSocket")
  end

  defp assert_asset_response(action, expected_body) do
    digest = apply(SquidSonarWeb.Assets, :"#{action}_digest", [])

    conn =
      :get
      |> Plug.Test.conn("/sonar/vendor/#{action}-#{digest}")
      |> Map.put(:params, %{"digest" => digest})

    conn = apply(SquidSonarWeb.Assets, action, [conn, %{}])

    assert conn.status == 200
    assert Plug.Conn.get_resp_header(conn, "content-type") == ["text/javascript; charset=utf-8"]
    assert conn.resp_body =~ expected_body
  end
end
