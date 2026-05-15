defmodule SquidSonarWeb.PageLive do
  use SquidSonarWeb, :live_view

  alias SquidSonar.Dashboard

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign_new(:prefix, fn -> "" end)
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
  def handle_event("paginate", %{"page" => page}, socket) do
    dashboard = socket.assigns.dashboard

    {:noreply,
     assign_dashboard(socket,
       filters: dashboard.filters,
       page_size: dashboard.page_size,
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
    <main class={["squid-sonar-shell", "squid-sonar-theme-#{@theme}"]}>
      <header class="squid-sonar-topbar">
        <div class="squid-sonar-brand">
          <div>
            <p class="squid-sonar-eyebrow">Squid Mesh runtime</p>
            <h1>Runtime dashboard</h1>
          </div>
        </div>
        <div class="squid-sonar-topbar-actions">
          <.theme_switcher theme={@theme} />
          <button
            class="squid-sonar-icon-button squid-sonar-refresh"
            type="button"
            phx-click="refresh"
            title="Refresh"
            aria-label="Refresh"
          >
            <svg
              aria-hidden="true"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="1.8"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <path d="M20 11a8.1 8.1 0 0 0-15.5-2" />
              <path d="M4 5v4h4" />
              <path d="M4 13a8.1 8.1 0 0 0 15.5 2" />
              <path d="M20 19v-4h-4" />
            </svg>
          </button>
        </div>
      </header>

      <%= if @dashboard.load_error do %>
        <.dashboard_error error={@dashboard.load_error} />
      <% else %>
        <div class="squid-sonar-content">
          <section class="squid-sonar-summary" aria-label="Run status counts">
            <div class="squid-sonar-metrics">
              <.status_metric
                :for={status <- @dashboard.statuses}
                status={status}
                count={Map.fetch!(@dashboard.status_counts, status)}
              />
            </div>
          </section>

          <form phx-change="filter" phx-submit="filter">
            <section class="squid-sonar-toolbar" aria-label="Filter runs">
              <div class="squid-sonar-filter-row">
                <div class="squid-sonar-filter-group">
                  <span class="squid-sonar-toolbar-label">Inspect runs</span>
                  <strong>{@dashboard.filtered_count} matching</strong>
                </div>

                <div class="squid-sonar-toolbar-controls">
                  <label class="squid-sonar-page-size">
                    <span>Page size</span>
                    <select name="page_size">
                      <option
                        :for={page_size <- @dashboard.page_sizes}
                        value={page_size}
                        selected={page_size == @dashboard.page_size}
                      >
                        {page_size}
                      </option>
                    </select>
                  </label>

                  <label class="squid-sonar-search">
                    <span>Search</span>
                    <input
                      type="search"
                      name="filters[query]"
                      value={@dashboard.filters.query}
                      placeholder="Workflow, trigger, step, run ID"
                      phx-debounce="250"
                    />
                  </label>
                </div>
              </div>
            </section>

            <section class="squid-sonar-workspace">
              <aside class="squid-sonar-sidebar" aria-label="Status inventory">
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

              <section class="squid-sonar-panel">
                <div class="squid-sonar-panel-heading">
                  <div>
                    <h2>Recent runs</h2>
                    <p>
                      Sorted by latest update. Last updated
                      <.timestamp value={@dashboard.loaded_at} />
                    </p>
                  </div>
                  <span class="squid-sonar-run-total">
                    Page {@dashboard.page} of {@dashboard.total_pages}
                  </span>
                </div>

                <%= if @dashboard.runs == [] do %>
                  <.empty_runs />
                <% else %>
                  <.runs_table runs={@dashboard.runs} prefix={@prefix} />
                  <.pagination
                    page={@dashboard.page}
                    total_pages={@dashboard.total_pages}
                    filtered_count={@dashboard.filtered_count}
                  />
                <% end %>
              </section>
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
