defmodule SquidSonarWeb.CoreComponents do
  @moduledoc false

  use Phoenix.Component

  alias SquidSonarWeb.WorkflowGraphLayout

  attr :status, :atom, required: true

  def status_badge(assigns) do
    ~H"""
    <span class={["squid-sonar-badge", "squid-sonar-badge-#{@status}"]}>
      {@status}
    </span>
    """
  end

  attr :status, :atom, required: true
  attr :count, :integer, required: true
  attr :active, :boolean, default: false

  def status_nav_item(assigns) do
    ~H"""
    <label class={["squid-sonar-nav-item", @active && "is-active"]}>
      <input type="radio" name="filters[status]" value={@status} checked={@active} />
      <span class="squid-sonar-nav-label">
        <span>{human_status(@status)}</span>
      </span>
      <strong>{@count}</strong>
    </label>
    """
  end

  attr :theme, :atom, required: true

  def theme_switcher(assigns) do
    ~H"""
    <div class="squid-sonar-theme-switcher" aria-label="Theme">
      <.theme_button theme={@theme} value={:system} label="Use system theme">
        <rect x="3" y="4" width="18" height="12" rx="2" />
        <path d="M8 20h8" />
        <path d="M12 16v4" />
      </.theme_button>
      <.theme_button theme={@theme} value={:light} label="Use light theme">
        <path d="M12 3v2" />
        <path d="M12 19v2" />
        <path d="m5.6 5.6 1.4 1.4" />
        <path d="m17 17 1.4 1.4" />
        <path d="M3 12h2" />
        <path d="M19 12h2" />
        <path d="m5.6 18.4 1.4-1.4" />
        <path d="m17 7 1.4-1.4" />
        <circle cx="12" cy="12" r="4" />
      </.theme_button>
      <.theme_button theme={@theme} value={:dark} label="Use dark theme">
        <path d="M20 14.4A7.8 7.8 0 0 1 9.6 4a8 8 0 1 0 10.4 10.4Z" />
      </.theme_button>
    </div>
    """
  end

  def refresh_button(assigns) do
    ~H"""
    <button
      class="squid-sonar-icon-button squid-sonar-refresh"
      type="button"
      phx-click="refresh"
      title="Refresh runs"
      aria-label="Refresh runs"
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
    """
  end

  attr :theme, :atom, required: true
  attr :value, :atom, required: true
  attr :label, :string, required: true
  slot :inner_block, required: true

  defp theme_button(assigns) do
    ~H"""
    <button
      class={["squid-sonar-icon-button", @theme == @value && "is-active"]}
      type="button"
      phx-click="set_theme"
      phx-value-theme={@value}
      data-squid-sonar-theme={@value}
      title={@label}
      aria-label={@label}
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
        {render_slot(@inner_block)}
      </svg>
    </button>
    """
  end

  attr :error, :any, required: true

  def dashboard_error(assigns) do
    ~H"""
    <section class="squid-sonar-alert" role="alert">
      <h2>Unable to load runs</h2>
      <p>Check the host application's Squid Mesh configuration and logs.</p>
    </section>
    """
  end

  def empty_runs(assigns) do
    ~H"""
    <div class="squid-sonar-empty">
      <h3>No runs found</h3>
    </div>
    """
  end

  attr :charts, :map, required: true

  def dashboard_charts(assigns) do
    ~H"""
    <section class="squid-sonar-charts" aria-label="Operational charts">
      <.chart_panel chart={@charts.activity} id="squid-sonar-activity-chart" />
      <.chart_panel chart={@charts.latency} id="squid-sonar-latency-chart" />
    </section>
    """
  end

  attr :chart, :map, required: true
  attr :id, :string, required: true

  def chart_panel(assigns) do
    ~H"""
    <article
      id={@id}
      class="squid-sonar-chart"
      phx-hook="SquidSonarChart"
      data-chart={chart_payload(@chart)}
    >
      <div class="squid-sonar-chart-heading">
        <h2>{@chart.title}</h2>
        <div class="squid-sonar-chart-legend" aria-hidden="true">
          <span :for={series <- @chart.series}>
            <i></i>
            {series.label}
          </span>
        </div>
      </div>
      <canvas aria-label={@chart.title} role="img"></canvas>
      <div class="squid-sonar-chart-tooltip" hidden></div>
    </article>
    """
  end

  attr :dashboard, :map, required: true
  attr :prefix, :string, default: ""

  def runs_panel(assigns) do
    ~H"""
    <section class="squid-sonar-panel">
      <div class="squid-sonar-panel-heading">
        <div class="squid-sonar-panel-title">
          <h2>Workflow runs</h2>
          <p>Recent execution activity across the host runtime.</p>
        </div>

        <div class="squid-sonar-panel-actions">
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

        <div class="squid-sonar-panel-tools">
          <.refresh_button />
        </div>
      </div>

      <%= if @dashboard.runs == [] do %>
        <.empty_runs />
      <% else %>
        <.runs_table runs={@dashboard.runs} prefix={@prefix} />
        <.pagination
          page={@dashboard.page}
          total_pages={@dashboard.total_pages}
          filtered_count={@dashboard.filtered_count}
          loaded_at={@dashboard.loaded_at}
          page_size={@dashboard.page_size}
          page_sizes={@dashboard.page_sizes}
        />
      <% end %>
    </section>
    """
  end

  attr :runs, :list, required: true
  attr :prefix, :string, default: ""

  def runs_table(assigns) do
    ~H"""
    <div class="squid-sonar-table-wrap">
      <table class="squid-sonar-table">
        <thead>
          <tr>
            <th>Workflow</th>
            <th>Trigger</th>
            <th>Status</th>
            <th>Current step</th>
            <th>Updated</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={run <- @runs}>
            <td>
              <div class="squid-sonar-run-title">
                <.link navigate={run_path(@prefix, run.id)} class="squid-sonar-run-link">
                  <span class="squid-sonar-primary">{format_workflow(run.workflow)}</span>
                  <span class="squid-sonar-secondary">{run.id}</span>
                </.link>
              </div>
            </td>
            <td>{format_value(run.trigger)}</td>
            <td><.status_badge status={run.status} /></td>
            <td>{format_step(run.current_step)}</td>
            <td><.timestamp value={run.updated_at} /></td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  attr :page, :integer, required: true
  attr :total_pages, :integer, required: true
  attr :filtered_count, :integer, required: true
  attr :loaded_at, :any, required: true
  attr :page_size, :integer, required: true
  attr :page_sizes, :list, required: true

  def pagination(assigns) do
    assigns =
      assigns
      |> assign(:previous_page, max(assigns.page - 1, 1))
      |> assign(:next_page, min(assigns.page + 1, assigns.total_pages))

    ~H"""
    <nav class="squid-sonar-pagination" aria-label="Runs pagination">
      <span class="squid-sonar-pagination-summary">
        <strong>Recent runs</strong>
        <span>{@filtered_count} matching</span>
        <span>Updated <.timestamp value={@loaded_at} /></span>
      </span>
      <div class="squid-sonar-pagination-controls">
        <label class="squid-sonar-page-size">
          <span>Page size</span>
          <select name="page_size">
            <option
              :for={page_size <- @page_sizes}
              value={page_size}
              selected={page_size == @page_size}
            >
              {page_size}
            </option>
          </select>
        </label>
        <button
          type="button"
          phx-click="paginate"
          phx-value-page={@previous_page}
          disabled={@page <= 1}
        >
          Previous
        </button>
        <strong>{@page} / {@total_pages}</strong>
        <button
          type="button"
          phx-click="paginate"
          phx-value-page={@next_page}
          disabled={@page >= @total_pages}
        >
          Next
        </button>
      </div>
    </nav>
    """
  end

  attr :detail, :map, required: true
  attr :prefix, :string, default: ""

  def run_detail(assigns) do
    ~H"""
    <section class="squid-sonar-detail">
      <header class="squid-sonar-detail-header">
        <div>
          <.link navigate={@prefix <> "/"} class="squid-sonar-back-link">Back to runs</.link>
          <span class="squid-sonar-section-label">Run summary</span>
          <h2>{format_workflow(@detail.summary.workflow)}</h2>
          <p>{@detail.summary.id}</p>
        </div>
        <.status_badge status={@detail.summary.status} />
      </header>

      <div class="squid-sonar-detail-grid">
        <.detail_item label="Trigger" value={format_value(@detail.summary.trigger)} />
        <.detail_item label="Current step" value={format_step(@detail.summary.current_step)} />
        <.detail_item label="Inserted" value={format_time(@detail.summary.inserted_at)} />
        <.detail_item label="Updated" value={format_time(@detail.summary.updated_at)} />
      </div>

      <div class="squid-sonar-detail-columns">
        <section class="squid-sonar-detail-panel">
          <h3>Diagnosis</h3>
          <.detail_item label="Reason" value={explanation_reason(@detail.explanation)} />
          <.detail_item label="Suggested actions" value={next_actions(@detail.explanation)} />
          <.detail_item label="Last error" value={last_error(@detail.last_error)} variant={:code} />
        </section>

        <section class="squid-sonar-detail-panel">
          <h3>History</h3>
          <.detail_item label="Step records" value={length(@detail.step_runs)} />
          <.detail_item label="Attempts" value={length(@detail.step_attempts)} />
          <.detail_item label="Audit events" value={length(@detail.audit_events)} />
        </section>
      </div>

      <section class="squid-sonar-detail-panel">
        <h3>Workflow</h3>
        <%= if @detail.workflow_graph.nodes == [] do %>
          <p class="squid-sonar-muted-line">No workflow graph loaded.</p>
        <% else %>
          <div class="squid-sonar-workflow-graph">
            <% layout = workflow_graph_layout(@detail.workflow_graph) %>

            <div class="squid-sonar-workflow-graph-heading">
              <div>
                <strong>{format_workflow(@detail.summary.workflow)}</strong>
                <span>{format_value(@detail.summary.trigger)}</span>
              </div>
            </div>

            <div
              class="squid-sonar-workflow-stage"
              style={workflow_stage_style(layout)}
            >
              <span
                :for={segment <- layout.segments}
                class={[
                  "squid-sonar-workflow-edge-segment",
                  "squid-sonar-workflow-edge-segment-#{segment.orientation}"
                ]}
                style={workflow_segment_style(segment)}
              />
              <span
                :for={port <- layout.ports}
                class="squid-sonar-workflow-port"
                style={workflow_port_style(port)}
              />

              <article
                :for={item <- layout.nodes}
                class={[
                  "squid-sonar-workflow-node",
                  "squid-sonar-workflow-node-#{item.node.status}",
                  item.node.current? && "squid-sonar-workflow-node-current",
                  item.node.terminal? && "squid-sonar-workflow-node-terminal"
                ]}
                style={workflow_node_style(item)}
              >
                <div class="squid-sonar-workflow-node-main">
                  <span class={[
                    "squid-sonar-workflow-status-icon",
                    "squid-sonar-workflow-status-icon-#{item.node.status}"
                  ]} />
                  <strong>{item.node.label}</strong>
                </div>
                <span class="squid-sonar-workflow-node-status">
                  {format_graph_status(item.node.status)}
                </span>
              </article>
            </div>
          </div>
        <% end %>
      </section>
    </section>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :variant, :atom, default: :strong

  def detail_item(assigns) do
    ~H"""
    <div class="squid-sonar-detail-item">
      <span>{@label}</span>
      <%= if @variant == :code do %>
        <code>{@value}</code>
      <% else %>
        <strong>{@value}</strong>
      <% end %>
    </div>
    """
  end

  attr :value, :any, required: true

  def timestamp(assigns) do
    ~H"""
    <time>{@value |> format_time()}</time>
    """
  end

  defp human_status(status) do
    status
    |> to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp format_workflow(nil), do: "Unknown workflow"

  defp format_workflow(workflow) when is_atom(workflow) do
    workflow
    |> Atom.to_string()
    |> String.replace_prefix("Elixir.", "")
  end

  defp format_workflow(workflow), do: to_string(workflow)

  defp format_step(nil), do: "None"
  defp format_step(step), do: format_value(step)

  defp format_value(nil), do: "None"
  defp format_value(value) when is_atom(value), do: Atom.to_string(value)
  defp format_value(value), do: to_string(value)

  defp format_time(nil), do: "Unknown"

  defp format_time(%DateTime{} = datetime) do
    datetime
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601()
  end

  defp format_time(%NaiveDateTime{} = datetime) do
    datetime
    |> NaiveDateTime.truncate(:second)
    |> NaiveDateTime.to_iso8601()
  end

  defp format_time(value), do: to_string(value)

  defp run_path(prefix, run_id), do: "#{prefix}/runs/#{run_id}"

  defp chart_payload(chart), do: Phoenix.json_library().encode!(chart)

  defp explanation_reason(nil), do: "Unknown"
  defp explanation_reason(%{reason: reason}), do: format_value(reason)
  defp explanation_reason(_explanation), do: "Unknown"

  defp next_actions(nil), do: "None"

  defp next_actions(%{next_actions: actions}) do
    case List.wrap(actions) do
      [] -> "None"
      actions -> Enum.map_join(actions, ", ", &format_value/1)
    end
  end

  defp next_actions(_explanation), do: "None"

  defp last_error(nil), do: "None"

  defp last_error(error) when is_map(error) do
    error
    |> Map.take([:code, :message, "code", "message"])
    |> case do
      empty when empty == %{} -> "Present"
      safe_error -> inspect(safe_error)
    end
  end

  defp last_error(_error), do: "Present"

  defp workflow_graph_layout(graph), do: WorkflowGraphLayout.build(graph)

  defp workflow_stage_style(%{width: width, height: height}) do
    "width: #{round(width)}px; height: #{round(height)}px;"
  end

  defp workflow_node_style(%{x: x, y: y, width: width, height: height}) do
    "left: #{round(x)}px; top: #{round(y)}px; width: #{round(width)}px; min-height: #{round(height)}px;"
  end

  defp workflow_segment_style(%{x: x, y: y, width: width, height: height}) do
    "left: #{round(x)}px; top: #{round(y)}px; width: #{round(width)}px; height: #{round(height)}px;"
  end

  defp workflow_port_style(%{x: x, y: y}) do
    "left: #{round(x)}px; top: #{round(y)}px;"
  end

  defp format_graph_status(:completed), do: "done"
  defp format_graph_status(:failed), do: "failed"
  defp format_graph_status(:retrying), do: "retrying"
  defp format_graph_status(:running), do: "running"
  defp format_graph_status(:paused), do: "paused"
  defp format_graph_status(:cancelled), do: "cancelled"
  defp format_graph_status(:waiting), do: "waiting"
  defp format_graph_status(:pending), do: "pending"
  defp format_graph_status(status), do: format_value(status)
end
