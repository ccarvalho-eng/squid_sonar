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

  const chartMax = (series) => {
    const values = series
      .flatMap((item) => item.values || [])
      .map(chartValue)
      .filter((value) => value !== null);

    return Math.max(1, ...values);
  };

  const niceChartMax = (value) => {
    if (value <= 5) return Math.ceil(value);
    const scale = Math.pow(10, Math.floor(Math.log10(value)));
    return Math.ceil(value / scale) * scale;
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

  const tooltipRows = (data, labelIndex) => {
    return (data.series || [])
      .map((item, index) => ({
        label: item.label,
        value: chartValue((item.values || [])[labelIndex]),
        index
      }))
      .filter((item) => item.value !== null);
  };

  const showChartTooltip = (container, canvas, point, data, styles) => {
    const tooltip = container.querySelector(".squid-sonar-chart-tooltip");
    if (!tooltip || !point) return;

    const title = document.createElement("strong");
    title.textContent = point.label;

    const rows = tooltipRows(data, point.index).map((item) => {
      const row = document.createElement("span");
      const marker = document.createElement("i");
      const label = document.createElement("span");
      const value = document.createElement("b");

      marker.style.background = chartColor(item.label, item.index, styles);
      label.textContent = item.label;
      value.textContent = formatChartValue(item.value, data.unit);

      row.append(marker, label, value);
      return row;
    });

    tooltip.replaceChildren(title, ...rows);
    tooltip.hidden = false;
    tooltip.style.left =
      Math.min(Math.max(point.x + canvas.offsetLeft, 74), container.clientWidth - 74) + "px";
    tooltip.style.top = point.y + canvas.offsetTop + "px";
  };

  const hideChartTooltip = (container) => {
    const tooltip = container.querySelector(".squid-sonar-chart-tooltip");
    if (tooltip) tooltip.hidden = true;
  };

  const nearestChartPoint = (points, event, canvas) => {
    const rect = canvas.getBoundingClientRect();
    const x = event.clientX - rect.left;

    return points.reduce((nearest, point) => {
      const distance = Math.abs(point.x - x);
      if (!nearest || distance < nearest.distance) return { ...point, distance };
      return nearest;
    }, null);
  };

  const chartBars = (labels, series, plot, plotWidth, plotHeight, maxValue, styles) => {
    const groupWidth = plotWidth / Math.max(1, labels.length);
    const groupGap = Math.min(14, groupWidth * 0.28);
    const innerWidth = Math.max(4, groupWidth - groupGap);
    const barGap = series.length > 1 ? Math.min(5, innerWidth * 0.14) : 0;
    const barWidth = Math.max(3, (innerWidth - barGap * Math.max(0, series.length - 1)) / series.length);

    return labels.map((label, index) => {
      const groupLeft = plot.left + groupWidth * index + groupGap / 2;
      const baseline = plot.top + plotHeight;
      const bars = series
        .map((item, seriesIndex) => {
          const value = chartValue((item.values || [])[index]);
          if (value === null) return null;

          const height = value <= 0 ? 0 : Math.max(2, (value / maxValue) * plotHeight);
          return {
            value,
            color: chartColor(item.label, seriesIndex, styles),
            x: groupLeft + seriesIndex * (barWidth + barGap),
            y: baseline - height,
            width: barWidth,
            height
          };
        })
        .filter(Boolean);

      return {
        index,
        label,
        bars,
        x: groupLeft + innerWidth / 2,
        y: bars.reduce((top, bar) => Math.min(top, bar.y), baseline)
      };
    });
  };

  const drawRoundedBar = (context, bar) => {
    if (bar.height <= 0) return;

    const radius = Math.min(3, bar.width / 2, bar.height / 2);
    context.beginPath();
    if (context.roundRect) {
      context.roundRect(bar.x, bar.y, bar.width, bar.height, radius);
    } else {
      context.rect(bar.x, bar.y, bar.width, bar.height);
    }
    context.fill();
  };

  const drawSeriesBars = (context, groups) => {
    groups.forEach((group) => {
      group.bars.forEach((bar) => {
        context.fillStyle = bar.color;
        drawRoundedBar(context, bar);
      });
    });
  };

  const drawChart = (container) => {
    const canvas = container.querySelector("canvas");
    if (!canvas) return;

    let data = {};
    try {
      data = JSON.parse(container.dataset.chart || "{}");
    } catch (_error) {
      return;
    }

    const labels = data.labels || [];
    const series = data.series || [];
    if (labels.length === 0 || series.length === 0) return;

    const rect = canvas.getBoundingClientRect();
    const width = Math.max(280, Math.floor(rect.width || container.clientWidth || 280));
    const height = Math.max(164, Math.floor(rect.height || 164));
    const ratio = window.devicePixelRatio || 1;
    canvas.width = width * ratio;
    canvas.height = height * ratio;
    canvas.style.width = width + "px";
    canvas.style.height = height + "px";

    const context = canvas.getContext("2d");
    context.setTransform(ratio, 0, 0, ratio, 0, 0);
    context.clearRect(0, 0, width, height);

    const shell = container.closest(".squid-sonar-shell") || document.documentElement;
    const styles = getComputedStyle(shell);
    const textColor = styles.getPropertyValue("--squid-sonar-muted").trim() || "#675f72";
    const gridColor = styles.getPropertyValue("--squid-sonar-border").trim() || "#ddd7e5";
    const plot = { left: 12, top: 10, right: 12, bottom: 26 };
    const plotWidth = width - plot.left - plot.right;
    const plotHeight = height - plot.top - plot.bottom;
    const maxValue = niceChartMax(chartMax(series));
    const points = [];

    context.font = "11px -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Segoe UI', sans-serif";
    context.lineWidth = 1;
    context.strokeStyle = gridColor;
    context.fillStyle = textColor;
    context.textBaseline = "middle";

    [0, 0.25, 0.5, 0.75, 1].forEach((step) => {
      const y = plot.top + plotHeight * step;
      context.save();
      context.globalAlpha = step === 1 ? 0.42 : 0.18;
      context.beginPath();
      context.moveTo(plot.left, y);
      context.lineTo(width - plot.right, y);
      context.stroke();
      context.restore();
    });

    context.textBaseline = "alphabetic";
    labels.forEach((label, index) => {
      if (labels.length > 4 && index % 2 !== 0 && index !== labels.length - 1) return;

      const x = plot.left + (plotWidth / Math.max(1, labels.length)) * (index + 0.5);
      context.textAlign = index === labels.length - 1 ? "right" : "center";
      context.fillText(label, Math.min(x, width - plot.right), height - 8);
    });

    const bars = chartBars(labels, series, plot, plotWidth, plotHeight, maxValue, styles);
    drawSeriesBars(context, bars);
    points.push(...bars);

    container.__squidSonarChart = { data, points, styles };
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
        this.chartResizeHandler = () => drawChart(this.el);
        this.chartPointerHandler = (event) => {
          const canvas = this.el.querySelector("canvas");
          const state = this.el.__squidSonarChart;
          if (!canvas || !state) return;

          const point = nearestChartPoint(state.points, event, canvas);
          showChartTooltip(this.el, canvas, point, state.data, state.styles);
        };
        this.chartLeaveHandler = () => hideChartTooltip(this.el);
        drawChart(this.el);
        window.addEventListener("resize", this.chartResizeHandler);
        this.el.addEventListener("pointermove", this.chartPointerHandler);
        this.el.addEventListener("pointerleave", this.chartLeaveHandler);
      },
      updated() {
        drawChart(this.el);
      },
      destroyed() {
        window.removeEventListener("resize", this.chartResizeHandler);
        this.el.removeEventListener("pointermove", this.chartPointerHandler);
        this.el.removeEventListener("pointerleave", this.chartLeaveHandler);
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

  defp send_js(conn, body) do
    conn
    |> put_resp_content_type("text/javascript")
    |> put_resp_header("cache-control", "public, max-age=31536000, immutable")
    |> put_private(:plug_skip_csrf_protection, true)
    |> send_resp(200, body)
  end
end
