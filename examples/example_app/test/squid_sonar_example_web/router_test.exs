defmodule SquidSonarExampleWeb.RouterTest do
  use ExUnit.Case, async: true

  test "mounts the example home page and SquidSonar routes" do
    routes = Phoenix.Router.routes(SquidSonarExampleWeb.Router)

    assert Enum.any?(routes, &(&1.path == "/" and &1.plug == SquidSonarExampleWeb.PageController))
    assert Enum.any?(routes, &(&1.path == "/sonar" and &1.plug == Phoenix.LiveView.Plug))

    assert Enum.any?(
             routes,
             &(&1.path == "/sonar/css-:digest" and &1.plug == SquidSonarWeb.Assets)
           )
  end
end
