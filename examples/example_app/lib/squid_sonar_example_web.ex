defmodule SquidSonarExampleWeb do
  @moduledoc false

  def controller do
    quote do
      use Phoenix.Controller,
        formats: [:html],
        layouts: [html: SquidSonarExampleWeb.Layouts]

      import Plug.Conn
      unquote(verified_routes())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      import Phoenix.HTML
      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: SquidSonarExampleWeb.Endpoint,
        router: SquidSonarExampleWeb.Router
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
