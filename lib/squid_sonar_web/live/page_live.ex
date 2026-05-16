defmodule SquidSonarWeb.PageLive do
  use SquidSonarWeb, :live_view

  alias SquidSonar.Dashboard

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign_new(:prefix, fn -> "" end)
      |> assign(:page_title, "SquidSonar Runtime")
      |> assign(:theme, :system)
      |> assign_dashboard()

    {:ok, socket}
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    dashboard = socket.assigns.dashboard

    {:noreply,
     assign_dashboard(socket,
       filters: dashboard.filters,
       page: dashboard.page,
       page_size: dashboard.page_size
     )}
  end

  @impl true
  def handle_event("filter", params, socket) do
    {:noreply,
     assign_dashboard(socket,
       filters: Map.get(params, "filters", %{}),
       page_size: Map.get(params, "page_size"),
       page: 1
     )}
  end

  @impl true
  def handle_event("paginate", %{"page" => page} = params, socket) do
    dashboard = socket.assigns.dashboard

    {:noreply,
     assign_dashboard(socket,
       filters: dashboard.filters,
       page_size:
         Map.get(params, "page_size") || Map.get(params, "page-size") || dashboard.page_size,
       page: page
     )}
  end

  @impl true
  def handle_event("set_theme", %{"theme" => theme}, socket) do
    {:noreply, assign(socket, :theme, normalize_theme(theme))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main
      id="squid-sonar-page"
      phx-hook="SquidSonarTheme"
      class={["squid-sonar-shell", "squid-sonar-theme-#{@theme}"]}
    >
      <header class="squid-sonar-topbar">
        <.link navigate={@prefix <> "/"} class="squid-sonar-brand squid-sonar-brand-link">
          <div>
            <p class="squid-sonar-eyebrow">Runtime dashboard</p>
            <h1>SquidSonar</h1>
          </div>
        </.link>
        <div class="squid-sonar-topbar-actions">
          <.theme_switcher theme={@theme} />
        </div>
      </header>

      <%= if @dashboard.load_error do %>
        <.dashboard_error error={@dashboard.load_error} />
      <% else %>
        <div class="squid-sonar-content">
          <input
            id="squid-sonar-filter-toggle"
            class="squid-sonar-filter-toggle-input"
            type="checkbox"
          />

          <form phx-change="filter" phx-submit="filter">
            <label class="squid-sonar-filter-toggle" for="squid-sonar-filter-toggle">
              <span class="squid-sonar-filter-toggle-icon" aria-hidden="true">
                <span></span>
                <span></span>
                <span></span>
              </span>
              <span>Filters</span>
            </label>

            <section class="squid-sonar-workspace">
              <aside class="squid-sonar-sidebar" aria-label="Status inventory">
                <div class="squid-sonar-sidebar-heading">
                  <div>
                    <h2>Status</h2>
                    <p>
                      <strong>{@dashboard.filtered_count}</strong>
                      <span>matching runs</span>
                    </p>
                  </div>
                </div>
                <.status_nav_item
                  status={:all}
                  count={@dashboard.loaded_count}
                  active={@dashboard.filters.status == :all}
                />
                <.status_nav_item
                  :for={status <- @dashboard.statuses}
                  status={status}
                  count={Map.fetch!(@dashboard.status_counts, status)}
                  active={@dashboard.filters.status == status}
                />
              </aside>

              <div class="squid-sonar-main-column">
                <.dashboard_charts charts={@dashboard.charts} />
                <.runs_panel dashboard={@dashboard} prefix={@prefix} />
              </div>
            </section>
          </form>
        </div>
      <% end %>
    </main>
    """
  end

  defp assign_dashboard(socket, opts \\ []) do
    assign(socket, :dashboard, Dashboard.load(opts))
  end

  defp normalize_theme("system"), do: :system
  defp normalize_theme("light"), do: :light
  defp normalize_theme("dark"), do: :dark
  defp normalize_theme(_theme), do: :system
end
