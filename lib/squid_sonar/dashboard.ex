defmodule SquidSonar.Dashboard do
  @moduledoc """
  Builds dashboard-ready runtime snapshots.
  """

  alias SquidSonar.Runs

  @statuses [:completed, :failed, :retrying, :paused, :running]
  @latency_statuses [:completed, :failed]
  @default_limit 250
  @default_page_size 10
  @page_sizes [10, 25, 50]
  @chart_days 7

  @type t :: %__MODULE__{
          runs: [SquidSonar.Runs.RunSummary.t()],
          statuses: [atom()],
          status_counts: %{atom() => non_neg_integer()},
          charts: map(),
          filters: map(),
          loaded_count: non_neg_integer(),
          filtered_count: non_neg_integer(),
          page: pos_integer(),
          page_size: pos_integer(),
          page_sizes: [pos_integer()],
          total_pages: pos_integer(),
          load_error: term() | nil,
          loaded_at: DateTime.t()
        }

  defstruct [
    :loaded_at,
    :load_error,
    filters: %{status: :all, query: ""},
    filtered_count: 0,
    loaded_count: 0,
    page: 1,
    page_size: @default_page_size,
    page_sizes: @page_sizes,
    runs: [],
    charts: %{},
    statuses: @statuses,
    status_counts: %{},
    total_pages: 1
  ]

  @doc """
  Loads recent runs and returns the dashboard snapshot.
  """
  @spec load(keyword()) :: t()
  def load(opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_limit)
    filters = normalize_filters(Keyword.get(opts, :filters, %{}))
    page_size = normalize_page_size(Keyword.get(opts, :page_size))
    requested_page = normalize_page(Keyword.get(opts, :page))
    loaded_at = Keyword.get_lazy(opts, :loaded_at, &DateTime.utc_now/0)
    runs_opts = Keyword.take(opts, [:client, :squid_mesh])

    case Runs.list_runs([limit: limit], runs_opts) do
      {:ok, runs} ->
        filtered_runs = filter_runs(runs, filters)
        total_pages = total_pages(filtered_runs, page_size)
        page = clamp_page(requested_page, total_pages)

        %__MODULE__{
          runs: paginate(filtered_runs, page, page_size),
          statuses: @statuses,
          status_counts: status_counts(runs),
          charts: charts(filtered_runs, loaded_at),
          filters: filters,
          loaded_count: length(runs),
          filtered_count: length(filtered_runs),
          page: page,
          page_size: page_size,
          page_sizes: @page_sizes,
          total_pages: total_pages,
          load_error: nil,
          loaded_at: loaded_at
        }

      {:error, reason} ->
        %__MODULE__{
          runs: [],
          statuses: @statuses,
          status_counts: status_counts([]),
          charts: charts([], loaded_at),
          filters: filters,
          loaded_count: 0,
          filtered_count: 0,
          page: 1,
          page_size: page_size,
          page_sizes: @page_sizes,
          total_pages: 1,
          load_error: reason,
          loaded_at: loaded_at
        }
    end
  end

  defp status_counts(runs) do
    base = Map.new(@statuses, &{&1, 0})

    Enum.reduce(runs, base, fn run, counts ->
      Map.update(counts, run.status, 1, &(&1 + 1))
    end)
  end

  defp charts(runs, loaded_at) do
    dates = chart_dates(loaded_at)
    labels = Enum.map(dates, &format_chart_date/1)

    %{
      activity: %{
        title: "Run activity",
        kind: :area,
        unit: :count,
        labels: labels,
        summary: activity_summary(runs, dates),
        series: activity_series(runs, dates)
      },
      latency: %{
        title: "Runtime latency",
        kind: :line,
        unit: :seconds,
        labels: labels,
        summary: latency_summary(runs, dates),
        series: latency_series(runs, dates)
      }
    }
  end

  defp chart_dates(loaded_at) do
    end_date =
      loaded_at
      |> sort_value()
      |> DateTime.to_date()

    end_date
    |> Date.add(-(@chart_days - 1))
    |> Date.range(end_date)
    |> Enum.to_list()
  end

  defp format_chart_date(date), do: Calendar.strftime(date, "%b %d")

  defp activity_series(runs, dates) do
    counts =
      runs
      |> Enum.group_by(&run_date/1)
      |> Map.new(fn {date, bucket_runs} -> {date, length(bucket_runs)} end)

    failures =
      runs
      |> Enum.filter(&(&1.status == :failed))
      |> Enum.group_by(&run_date/1)
      |> Map.new(fn {date, bucket_runs} -> {date, length(bucket_runs)} end)

    [
      %{
        label: "Total",
        values: Enum.map(dates, &Map.get(counts, &1, 0))
      },
      %{
        label: "Failed",
        values: Enum.map(dates, &Map.get(failures, &1, 0))
      }
    ]
  end

  defp activity_summary(runs, dates) do
    date_set = MapSet.new(dates)
    total = Enum.count(runs, &(run_date(&1) in date_set))

    %{value: total, label: "runs in 7 days"}
  end

  defp latency_series(runs, dates) do
    durations_by_date =
      runs
      |> Enum.filter(&(&1.status in @latency_statuses))
      |> Enum.reduce(%{}, fn run, durations ->
        case run_duration_seconds(run) do
          nil -> durations
          duration -> Map.update(durations, run_date(run), [duration], &[duration | &1])
        end
      end)

    [
      %{
        label: "Median",
        values: Enum.map(dates, &percentile(Map.get(durations_by_date, &1, []), 50))
      },
      %{
        label: "P95",
        values: Enum.map(dates, &percentile(Map.get(durations_by_date, &1, []), 95))
      }
    ]
  end

  defp latency_summary(runs, dates) do
    date_set = MapSet.new(dates)

    durations =
      runs
      |> Enum.filter(&(&1.status in @latency_statuses and run_date(&1) in date_set))
      |> Enum.map(&run_duration_seconds/1)
      |> Enum.reject(&is_nil/1)

    %{value: percentile(durations, 95), label: "p95 runtime"}
  end

  defp run_date(run) do
    run.updated_at
    |> sort_value()
    |> DateTime.to_date()
  end

  defp run_duration_seconds(run) do
    inserted_at = datetime_value(run.inserted_at)
    updated_at = datetime_value(run.updated_at)

    with %DateTime{} <- inserted_at,
         %DateTime{} <- updated_at do
      diff = DateTime.diff(updated_at, inserted_at, :second)
      if diff >= 0, do: diff
    else
      _invalid -> nil
    end
  end

  defp datetime_value(nil), do: nil
  defp datetime_value(%DateTime{} = datetime), do: datetime
  defp datetime_value(%NaiveDateTime{} = datetime), do: DateTime.from_naive!(datetime, "Etc/UTC")
  defp datetime_value(_value), do: nil

  defp percentile([], _percentile), do: nil

  defp percentile(values, percentile) do
    sorted_values = Enum.sort(values)

    index =
      sorted_values
      |> length()
      |> Kernel.*(percentile)
      |> Kernel./(100)
      |> Float.ceil()
      |> trunc()
      |> max(1)

    sorted_values
    |> Stream.drop(index - 1)
    |> Enum.take(1)
    |> case do
      [value] -> value
      [] -> nil
    end
  end

  defp normalize_filters(filters) do
    %{
      status: normalize_status(filter_value(filters, :status)),
      query: normalize_query(filter_value(filters, :query))
    }
  end

  defp filter_value(filters, key) when is_map(filters) do
    Map.get(filters, key) || Map.get(filters, to_string(key))
  end

  defp filter_value(filters, key) when is_list(filters) do
    Enum.find_value(filters, fn
      {filter_key, value} ->
        if filter_key == key or filter_key == to_string(key), do: value

      _filter ->
        nil
    end)
  end

  defp filter_value(_filters, _key), do: nil

  defp normalize_status(status) when status in [nil, "", :all, "all"], do: :all

  defp normalize_status(status) do
    Enum.find(@statuses, :all, &(to_string(&1) == to_string(status)))
  end

  defp normalize_query(nil), do: ""

  defp normalize_query(query) do
    query
    |> to_string()
    |> String.trim()
  end

  defp filter_runs(runs, filters) do
    runs
    |> Enum.filter(fn run ->
      status_matches?(run, filters.status) and query_matches?(run, filters.query)
    end)
    |> Enum.sort_by(&sort_value(&1.updated_at), {:desc, DateTime})
  end

  defp status_matches?(_run, :all), do: true
  defp status_matches?(run, status), do: run.status == status

  defp query_matches?(_run, ""), do: true

  defp query_matches?(run, query) do
    run
    |> searchable_text()
    |> String.contains?(String.downcase(query))
  end

  defp searchable_text(run) do
    [run.id, run.workflow, run.trigger, run.status, run.current_step]
    |> Enum.map(&format_search_value/1)
    |> Enum.join(" ")
    |> String.downcase()
  end

  defp format_search_value(nil), do: ""

  defp format_search_value(value) when is_atom(value) do
    value
    |> Atom.to_string()
    |> String.replace_prefix("Elixir.", "")
  end

  defp format_search_value(value), do: to_string(value)

  defp sort_value(nil), do: ~U[0001-01-01 00:00:00Z]
  defp sort_value(%DateTime{} = datetime), do: datetime
  defp sort_value(%NaiveDateTime{} = datetime), do: DateTime.from_naive!(datetime, "Etc/UTC")
  defp sort_value(_value), do: ~U[0001-01-01 00:00:00Z]

  defp normalize_page_size(page_size) do
    page_size = parse_positive_integer(page_size, @default_page_size)

    if page_size in @page_sizes do
      page_size
    else
      @default_page_size
    end
  end

  defp normalize_page(page), do: parse_positive_integer(page, 1)

  defp parse_positive_integer(value, _fallback) when is_integer(value) and value > 0, do: value

  defp parse_positive_integer(value, fallback) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} when integer > 0 -> integer
      _invalid -> fallback
    end
  end

  defp parse_positive_integer(_value, fallback), do: fallback

  defp total_pages([], _page_size), do: 1

  defp total_pages(runs, page_size) do
    runs
    |> length()
    |> Kernel./(page_size)
    |> Float.ceil()
    |> trunc()
  end

  defp clamp_page(page, total_pages), do: min(page, total_pages)

  defp paginate(runs, page, page_size) do
    offset = (page - 1) * page_size
    Enum.slice(runs, offset, page_size)
  end
end
