defmodule SquidSonarWeb do
  @moduledoc false

  def live_view do
    quote do
      use Phoenix.LiveView

      import SquidSonarWeb.CoreComponents
    end
  end

  def html do
    quote do
      use Phoenix.Component

      import Phoenix.HTML
      import SquidSonarWeb.CoreComponents

      alias Phoenix.LiveView.JS
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
