defmodule SquidSonarWeb.Assets do
  @moduledoc false

  use Phoenix.Controller, formats: []

  @static_path Path.expand("../../../priv/static", __DIR__)
  @external_resource css_path = Path.join(@static_path, "squid_sonar.css")
  @css File.read!(css_path)
  @css_digest Base.encode16(:crypto.hash(:md5, @css), case: :lower) |> String.slice(0, 8)

  @external_resource phoenix_path = Application.app_dir(:phoenix, "priv/static/phoenix.mjs")
  @phoenix_js File.read!(phoenix_path)
  @phoenix_digest Base.encode16(:crypto.hash(:md5, @phoenix_js), case: :lower)
                  |> String.slice(0, 8)

  @external_resource live_view_path =
                       Application.app_dir(
                         :phoenix_live_view,
                         "priv/static/phoenix_live_view.esm.js"
                       )
  @live_view_js File.read!(live_view_path)
  @live_view_digest Base.encode16(:crypto.hash(:md5, @live_view_js), case: :lower)
                    |> String.slice(0, 8)

  @external_resource chart_path = Path.join(@static_path, "vendor/chart.umd.min.js")
  @chart_js File.read!(chart_path)
  @chart_digest Base.encode16(:crypto.hash(:md5, @chart_js), case: :lower) |> String.slice(0, 8)

  @js """
  import { Socket, LongPoll } from "./vendor/phoenix-#{@phoenix_digest}";
  import { LiveSocket } from "./vendor/live-view-#{@live_view_digest}";

  const csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content");
  const script = document.querySelector("script[data-squid-sonar-client]");
  const livePath = script?.dataset.livePath || "/live";
  const liveTransport = script?.dataset.liveTransport || "websocket";
  const socketOptions = { params: { _csrf_token: csrfToken } };
  const themeStorageKey = "squid-sonar-theme";
  const themes = new Set(["system", "light", "dark"]);

  const storedTheme = () => {
    try {
      const theme = window.localStorage.getItem(themeStorageKey);
      return themes.has(theme) ? theme : null;
    } catch (_error) {
      return null;
    }
  };

  const storeTheme = (theme) => {
    if (!themes.has(theme)) return;

    try {
      window.localStorage.setItem(themeStorageKey, theme);
    } catch (_error) {
      return;
    }
  };

  const applyTheme = (theme) => {
    if (!themes.has(theme)) return;

    document.querySelectorAll(".squid-sonar-shell").forEach((shell) => {
      shell.classList.remove(
        "squid-sonar-theme-system",
        "squid-sonar-theme-light",
        "squid-sonar-theme-dark"
      );
      shell.classList.add(`squid-sonar-theme-${theme}`);
    });
  };

  const initialTheme = storedTheme();
  if (initialTheme) applyTheme(initialTheme);

  const chartValue = (value) => {
    if (value === null || value === undefined || Number.isNaN(Number(value))) return null;
    return Number(value);
  };

  const formatChartValue = (value, unit) => {
    if (value === null || value === undefined) return "";
    if (unit !== "seconds") return String(Math.round(value));
    if (value >= 3600) return Math.round(value / 360) / 10 + "h";
    if (value >= 60) return Math.round(value / 6) / 10 + "m";
    return Math.round(value) + "s";
  };

  const chartColor = (label, index, styles) => {
    const normalizedLabel = String(label || "").toLowerCase();
    if (normalizedLabel.includes("failed") || normalizedLabel.includes("p95")) {
      return styles.getPropertyValue("--squid-sonar-danger").trim() || "#8f3d39";
    }
    if (normalizedLabel.includes("running")) {
      return styles.getPropertyValue("--squid-sonar-muted").trim() || "#675f72";
    }
    if (index > 0) {
      return styles.getPropertyValue("--squid-sonar-border-strong").trim() || "#aaa1b8";
    }
    return styles.getPropertyValue("--squid-sonar-accent").trim() || "#8061d8";
  };

  const dashboardChartsData = (container) => {
    try {
      return JSON.parse(container.dataset.charts || "{}");
    } catch (_error) {
      return {};
    }
  };

  const dashboardChartData = (hook) => {
    const charts = dashboardChartsData(hook.el);
    const requestedChart = hook.activeChart || hook.el.dataset.activeChart || "activity";
    const activeChart = charts[requestedChart] ? requestedChart : "activity";
    hook.activeChart = activeChart;
    return charts[activeChart] || {};
  };

  const formatChartSummaryValue = (summary, unit) => {
    if (!summary || summary.value === null || summary.value === undefined) return "None";
    return formatChartValue(summary.value, unit);
  };

  const formatChartSummaryLabel = (summary) => {
    return summary?.label || "current window";
  };

  const dashboardChartStyles = (container) => {
    const shell = container.closest(".squid-sonar-shell") || document.documentElement;
    const styles = getComputedStyle(shell);
    return {
      border: styles.getPropertyValue("--squid-sonar-border").trim() || "#d8d8de",
      danger: styles.getPropertyValue("--squid-sonar-danger").trim() || "#a0443f",
      grid: styles.getPropertyValue("--squid-sonar-chart-grid").trim() || "#ececf0",
      muted: styles.getPropertyValue("--squid-sonar-muted").trim() || "#6e6e73",
      text: styles.getPropertyValue("--squid-sonar-text").trim() || "#1d1d1f",
      accent: styles.getPropertyValue("--squid-sonar-accent").trim() || "#8061d8",
      strong: styles.getPropertyValue("--squid-sonar-border-strong").trim() || "#a7a7b0"
    };
  };

  const chartDatasets = (data, styles) => {
    return (data.series || []).map((item, index) => {
      const color = chartColor(item.label, index, {
        getPropertyValue(name) {
          const values = {
            "--squid-sonar-accent": styles.accent,
            "--squid-sonar-border-strong": styles.strong,
            "--squid-sonar-danger": styles.danger,
            "--squid-sonar-muted": styles.muted
          };
          return values[name] || "";
        }
      });

      return {
        label: item.label,
        data: (item.values || []).map(chartValue),
        backgroundColor: color,
        borderColor: color,
        borderSkipped: false,
        borderRadius: 3,
        barThickness: 18,
        maxBarThickness: 20,
        minBarLength: 2
      };
    });
  };

  const chartOptions = (data, styles) => ({
    responsive: true,
    maintainAspectRatio: false,
    animation: false,
    interaction: {
      mode: "index",
      intersect: false
    },
    datasets: {
      bar: {
        categoryPercentage: 0.64,
        barPercentage: 0.82
      }
    },
    plugins: {
      legend: {
        display: false
      },
      tooltip: {
        mode: "index",
        intersect: false,
        backgroundColor: styles.text,
        borderColor: styles.border,
        borderWidth: 1,
        displayColors: true,
        titleColor: "#ffffff",
        bodyColor: "#ffffff",
        padding: 10,
        callbacks: {
          label(context) {
            return `${context.dataset.label}: ${formatChartValue(context.parsed.y, data.unit)}`;
          }
        }
      }
    },
    scales: {
      x: {
        border: { display: false },
        grid: { display: false },
        ticks: {
          color: styles.muted,
          font: { size: 11, weight: 600 },
          maxRotation: 0,
          autoSkip: true,
          maxTicksLimit: 5
        }
      },
      y: {
        beginAtZero: true,
        border: { display: false },
        grid: {
          color: styles.grid,
          lineWidth: 1,
          drawTicks: false
        },
        ticks: {
          color: styles.muted,
          font: { size: 11, weight: 600 },
          padding: 8,
          precision: data.unit === "seconds" ? 0 : undefined,
          callback(value) {
            return formatChartValue(value, data.unit);
          }
        }
      }
    }
  });

  const updateChartChrome = (hook, data) => {
    hook.el.dataset.activeChart = hook.activeChart;

    const title = hook.el.querySelector("[data-squid-sonar-chart-title]");
    if (title) title.textContent = data.title || "";

    const summaryValue = hook.el.querySelector("[data-squid-sonar-chart-summary-value]");
    if (summaryValue) summaryValue.textContent = formatChartSummaryValue(data.summary, data.unit);

    const summaryLabel = hook.el.querySelector("[data-squid-sonar-chart-summary-label]");
    if (summaryLabel) summaryLabel.textContent = formatChartSummaryLabel(data.summary);

    hook.el.querySelectorAll("[data-squid-sonar-chart-toggle]").forEach((button) => {
      button.classList.toggle("is-active", button.dataset.squidSonarChartToggle === hook.activeChart);
    });

    const legend = hook.el.querySelector("[data-squid-sonar-chart-legend]");
    if (legend) {
      legend.replaceChildren(
        ...(data.series || []).map((series) => {
          const item = document.createElement("span");
          const marker = document.createElement("i");
          item.append(marker, document.createTextNode(series.label));
          return item;
        })
      );
    }
  };

  const Hooks = {
    SquidSonarTheme: {
      mounted() {
        const theme = storedTheme();
        if (theme) this.pushEvent("set_theme", { theme });
      }
    },
    SquidSonarChart: {
      mounted() {
        this.charts = {};
        this.activeChart = this.el.dataset.activeChart || "activity";
        this.chartToggleHandler = (event) => {
          const button = event.target.closest("[data-squid-sonar-chart-toggle]");
          if (!button || !this.el.contains(button)) return;

          this.activeChart = button.dataset.squidSonarChartToggle || "activity";
          this.updateCharts();
        };
        this.el.addEventListener("click", this.chartToggleHandler);
        this.createCharts();
        this.updateCharts();
      },
      updated() {
        this.updateCharts();
      },
      createCharts() {
        const Chart = window.Chart;
        const canvas = this.el.querySelector("canvas");

        if (!Chart) {
          if (!this.chartRetryFrame) {
            this.chartRetryFrame = window.requestAnimationFrame(() => {
              this.chartRetryFrame = null;
              this.createCharts();
              this.updateCharts();
            });
          }
          return;
        }

        if (!canvas) return;

        this.charts.dashboard = new Chart(canvas, {
          type: "bar",
          data: { labels: [], datasets: [] },
          options: chartOptions({ unit: "count" }, dashboardChartStyles(this.el))
        });
      },
      updateCharts() {
        const chart = this.charts.dashboard;
        if (!chart) {
          this.createCharts();
          return;
        }

        const data = dashboardChartData(this);
        const labels = data.labels || [];
        const series = data.series || [];
        if (labels.length === 0 || series.length === 0) return;

        const styles = dashboardChartStyles(this.el);
        updateChartChrome(this, data);
        chart.data.labels = labels;
        chart.data.datasets = chartDatasets(data, styles);
        chart.options = chartOptions(data, styles);
        chart.update("none");
      },
      destroyed() {
        if (this.chartRetryFrame) window.cancelAnimationFrame(this.chartRetryFrame);
        this.el.removeEventListener("click", this.chartToggleHandler);
        Object.values(this.charts || {}).forEach((chart) => {
          if (chart) chart.destroy();
        });
        this.charts = {};
      }
    }
  };

  document.addEventListener("click", (event) => {
    const button = event.target.closest("[data-squid-sonar-theme]");
    if (!button) return;

    const theme = button.dataset.squidSonarTheme;
    storeTheme(theme);
    applyTheme(theme);
  });

  if (liveTransport === "longpoll") {
    socketOptions.transport = LongPoll;
  }

  socketOptions.hooks = Hooks;

  const liveSocket = new LiveSocket(livePath, Socket, socketOptions);
  liveSocket.connect();

  window.squidSonarLiveSocket = liveSocket;
  """
  @js_digest Base.encode16(:crypto.hash(:md5, @js), case: :lower) |> String.slice(0, 8)

  @doc false
  def digest, do: @css_digest

  @doc false
  def js_digest, do: @js_digest

  @doc false
  def chart_digest, do: @chart_digest

  @doc false
  def phoenix_digest, do: @phoenix_digest

  @doc false
  def live_view_digest, do: @live_view_digest

  @doc false
  def css(%{params: %{"digest" => digest}} = conn, _params) when digest == @css_digest do
    conn
    |> put_resp_content_type("text/css")
    |> put_resp_header("cache-control", "public, max-age=31536000, immutable")
    |> put_private(:plug_skip_csrf_protection, true)
    |> send_resp(200, @css)
  end

  def css(conn, _params) do
    send_resp(conn, 404, "Not Found")
  end

  @doc false
  def js(%{params: %{"digest" => digest}} = conn, _params) when digest == @js_digest do
    send_js(conn, @js)
  end

  def js(conn, _params) do
    send_resp(conn, 404, "Not Found")
  end

  @doc false
  def phoenix(%{params: %{"digest" => digest}} = conn, _params) when digest == @phoenix_digest do
    send_js(conn, @phoenix_js)
  end

  def phoenix(conn, _params) do
    send_resp(conn, 404, "Not Found")
  end

  @doc false
  def live_view(%{params: %{"digest" => digest}} = conn, _params)
      when digest == @live_view_digest do
    send_js(conn, @live_view_js)
  end

  def live_view(conn, _params) do
    send_resp(conn, 404, "Not Found")
  end

  @doc false
  def chart(%{params: %{"digest" => digest}} = conn, _params) when digest == @chart_digest do
    send_js(conn, @chart_js)
  end

  def chart(conn, _params) do
    send_resp(conn, 404, "Not Found")
  end

  defp send_js(conn, body) do
    conn
    |> put_resp_content_type("text/javascript")
    |> put_resp_header("cache-control", "public, max-age=31536000, immutable")
    |> put_private(:plug_skip_csrf_protection, true)
    |> send_resp(200, body)
  end
end
