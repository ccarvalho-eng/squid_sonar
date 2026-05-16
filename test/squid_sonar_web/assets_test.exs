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
    assert conn.resp_body =~ ".squid-sonar-chart-canvas"
    assert conn.resp_body =~ "--squid-sonar-accent: #8061d8;"
    assert conn.resp_body =~ ".squid-sonar-nav-item.is-active::before"

    assert conn.resp_body =~
             ".squid-sonar-filter-toggle-input:checked + form .squid-sonar-sidebar"

    refute conn.resp_body =~ "gradient"
    refute conn.resp_body =~ "box-shadow"
    refute conn.resp_body =~ "text-shadow"
    refute conn.resp_body =~ "#315f8f"
    refute conn.resp_body =~ "#8aa4c8"
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
    assert conn.resp_body =~ "SquidSonarChart"
    assert conn.resp_body =~ "new Chart"
    assert conn.resp_body =~ "createCharts"
    assert conn.resp_body =~ "updateCharts"
    assert conn.resp_body =~ "dashboardChartsData"
    assert conn.resp_body =~ "chartToggleHandler"
    assert conn.resp_body =~ "chartDatasets"
    assert conn.resp_body =~ "grid: {"
    assert conn.resp_body =~ "color: styles.grid"
    assert conn.resp_body =~ "lineWidth: 1"
    assert conn.resp_body =~ "--squid-sonar-chart-grid"
    refute conn.resp_body =~ "drawChart"
    refute conn.resp_body =~ "step === 1 ? 0."
  end

  test "serves packaged LiveView client dependencies" do
    assert_asset_response(:chart, "Chart.js")
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
