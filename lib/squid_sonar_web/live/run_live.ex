defmodule SquidSonarWeb.RunLive do
  use SquidSonarWeb, :live_view

  alias SquidSonar.Runs

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign_new(:prefix, fn -> "" end)
     |> assign(:page_title, "SquidSonar Run")
     |> assign(:theme, :system)}
  end

  @impl true
  def handle_params(%{"id" => run_id}, _uri, socket) do
    {:noreply, assign_run(socket, run_id)}
  end

  @impl true
  def handle_event("set_theme", %{"theme" => theme}, socket) do
    {:noreply, assign(socket, :theme, normalize_theme(theme))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main
      id="squid-sonar-run"
      phx-hook="SquidSonarTheme"
      class={["squid-sonar-shell", "squid-sonar-theme-#{@theme}"]}
    >
      <header class="squid-sonar-topbar">
        <.link navigate={@prefix <> "/"} class="squid-sonar-brand squid-sonar-brand-link">
          <div>
            <p class="squid-sonar-eyebrow">Run detail</p>
            <h1>SquidSonar</h1>
          </div>
        </.link>
        <.theme_switcher theme={@theme} />
      </header>

      <div class="squid-sonar-content">
        <%= if @load_error do %>
          <.dashboard_error error={@load_error} />
        <% else %>
          <.run_detail detail={@detail} prefix={@prefix} />
        <% end %>
      </div>
    </main>
    """
  end

  defp assign_run(socket, run_id) do
    case Runs.get_run(run_id) do
      {:ok, detail} ->
        socket
        |> assign(:detail, detail)
        |> assign(:load_error, nil)

      {:error, reason} ->
        socket
        |> assign(:detail, nil)
        |> assign(:load_error, reason)
    end
  end

  defp normalize_theme("system"), do: :system
  defp normalize_theme("light"), do: :light
  defp normalize_theme("dark"), do: :dark
  defp normalize_theme(_theme), do: :system
end
