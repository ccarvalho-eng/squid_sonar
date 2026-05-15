defmodule SquidSonarWeb.PageLive do
  use SquidSonarWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <main class="squid-sonar-shell">
      <header class="squid-sonar-header">
        <div>
          <p class="squid-sonar-eyebrow">Squid Mesh Runtime</p>
          <h1>SquidSonar</h1>
        </div>
        <.status_badge status={:scaffold} />
      </header>

      <section class="squid-sonar-panel">
        <h2>Runtime visibility is coming online.</h2>
        <p>
          This embedded surface will list Squid Mesh runs, explain stuck or failed
          workflows, and show step history without owning the host application.
        </p>
      </section>
    </main>
    """
  end
end
