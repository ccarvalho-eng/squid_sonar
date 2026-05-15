defmodule SquidSonarWeb.Hooks do
  @moduledoc false

  import Phoenix.Component, only: [assign: 3]

  def on_mount(:default, _params, session, socket) do
    socket =
      socket
      |> assign(:prefix, Map.fetch!(session, "prefix"))
      |> assign(:live_path, Map.fetch!(session, "live_path"))
      |> assign(:live_transport, Map.fetch!(session, "live_transport"))

    {:cont, socket}
  end
end
