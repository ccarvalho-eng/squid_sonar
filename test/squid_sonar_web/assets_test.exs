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
  end

  test "rejects stale CSS digests" do
    conn =
      :get
      |> Plug.Test.conn("/sonar/css-stale")
      |> Map.put(:params, %{"digest" => "stale"})
      |> SquidSonarWeb.Assets.css(%{})

    assert conn.status == 404
  end
end
