defmodule SquidSonarWeb.RunLive do
  use SquidSonarWeb, :live_view

  alias SquidSonar.Runs

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign_new(:prefix, fn -> "" end)
     |> assign_new(:control_actor, &SquidSonar.Router.default_control_actor/0)
     |> assign(:page_title, "SquidSonar Run")
     |> assign(:theme, :system)
     |> assign(:workflow_panel_view, :visual)}
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
  def handle_event("clear_flash", _params, socket) do
    {:noreply, clear_run_flash(socket)}
  end

  @impl true
  def handle_event("select_workflow_panel", %{"view" => view}, socket) do
    {:noreply, assign(socket, :workflow_panel_view, normalize_workflow_panel_view(view))}
  end

  @impl true
  def handle_event("cancel", %{"run-id" => run_id}, socket) do
    case Runs.cancel_run(run_id) do
      {:ok, _updated_run} ->
        {:noreply,
         socket
         |> put_run_flash(:info, "Run cancelled successfully")
         |> assign_run(run_id)}

      {:error, _reason} ->
        {:noreply, put_run_flash(socket, :error, "Failed to cancel run.")}
    end
  end

  @impl true
  def handle_event("resume", %{"run-id" => run_id}, socket) do
    case Runs.resume_run(run_id, control_attrs(socket)) do
      {:ok, _updated_run} ->
        {:noreply,
         socket
         |> put_run_flash(:info, "Run resumed successfully")
         |> assign_run(run_id)}

      {:error, _reason} ->
        {:noreply, put_run_flash(socket, :error, "Failed to resume run.")}
    end
  end

  @impl true
  def handle_event("approve", %{"run-id" => run_id}, socket) do
    case Runs.approve_run(run_id, control_attrs(socket)) do
      {:ok, _updated_run} ->
        {:noreply,
         socket
         |> put_run_flash(:info, "Run approved successfully")
         |> assign_run(run_id)}

      {:error, _reason} ->
        {:noreply, put_run_flash(socket, :error, "Failed to approve run.")}
    end
  end

  @impl true
  def handle_event("reject", %{"run-id" => run_id}, socket) do
    case Runs.reject_run(run_id, control_attrs(socket)) do
      {:ok, _updated_run} ->
        {:noreply,
         socket
         |> put_run_flash(:info, "Run rejected successfully")
         |> assign_run(run_id)}

      {:error, _reason} ->
        {:noreply, put_run_flash(socket, :error, "Failed to reject run.")}
    end
  end

  @impl true
  def handle_event("replay", %{"run-id" => run_id}, socket) do
    case Runs.replay_run(run_id) do
      {:ok, new_run} ->
        {:noreply,
         socket
         |> put_run_flash(:info, "Run replayed successfully")
         |> assign_run(new_run.run_id)}

      {:error, _reason} ->
        {:noreply, put_run_flash(socket, :error, "Failed to replay run.")}
    end
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

      <.flash_messages flash={visible_flash(assigns)} />

      <div class="squid-sonar-content">
        <%= if @load_error do %>
          <.dashboard_error error={@load_error} />
        <% else %>
          <.run_detail
            detail={@detail}
            prefix={@prefix}
            workflow_panel_view={@workflow_panel_view}
          />
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

  defp put_run_flash(socket, kind, message) do
    if Map.has_key?(socket.assigns, :flash) do
      put_flash(socket, kind, message)
    else
      assign(socket, :control_flash, %{Atom.to_string(kind) => message})
    end
  end

  defp visible_flash(assigns) do
    Map.get(assigns, :flash, Map.get(assigns, :control_flash, %{}))
  end

  defp clear_run_flash(socket) do
    if Map.has_key?(socket.assigns, :flash) do
      clear_flash(socket)
    else
      assign(socket, :control_flash, %{})
    end
  end

  defp control_attrs(socket) do
    %{actor: Map.get(socket.assigns, :control_actor, SquidSonar.Router.default_control_actor())}
  end

  defp normalize_theme("system"), do: :system
  defp normalize_theme("light"), do: :light
  defp normalize_theme("dark"), do: :dark
  defp normalize_theme(_theme), do: :system

  defp normalize_workflow_panel_view("raw"), do: :raw
  defp normalize_workflow_panel_view(_view), do: :visual
end
