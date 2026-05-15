defmodule SquidSonar.Router do
  @moduledoc """
  Router helpers for mounting SquidSonar inside a Phoenix application.

  The host owns its endpoint, authentication, layout, and deployment topology.
  SquidSonar contributes only the LiveView routes under the requested path.
  """

  @default_opts [
    socket_path: "/live",
    transport: "websocket"
  ]

  @transport_values ~w(longpoll websocket)

  defmacro __using__(_opts) do
    quote do
      import SquidSonar.Router, only: [squid_sonar: 1, squid_sonar: 2]
    end
  end

  @doc """
  Mounts SquidSonar under the given path.

      scope "/" do
        pipe_through [:browser]

        squid_sonar "/sonar", otp_app: :my_app
      end

  Supported options:

    * `:as` - route helper name for the mounted LiveView session.
    * `:socket_path` - LiveView socket path used by the host application.
      Defaults to `"/live"`.
    * `:transport` - LiveView client transport. Use `"websocket"` or
      `"longpoll"`. Defaults to `"websocket"`.
  """
  defmacro squid_sonar(path, opts \\ []) do
    quote bind_quoted: [path: path, opts: opts] do
      prefix = Phoenix.Router.scoped_path(__MODULE__, path)

      scope path, alias: false, as: false do
        import Phoenix.LiveView.Router, only: [live: 4, live_session: 3]

        {session_name, session_opts, route_opts} = SquidSonar.Router.__options__(prefix, opts)

        live_session session_name, session_opts do
          get "/css-:digest", SquidSonarWeb.Assets, :css, as: :squid_sonar_asset
          get "/js-:digest", SquidSonarWeb.Assets, :js, as: :squid_sonar_js
          get "/vendor/phoenix-:digest", SquidSonarWeb.Assets, :phoenix, as: :squid_sonar_phoenix

          get "/vendor/live-view-:digest", SquidSonarWeb.Assets, :live_view,
            as: :squid_sonar_live_view

          live "/", SquidSonarWeb.PageLive, :index, route_opts
          live "/runs/:id", SquidSonarWeb.RunLive, :show, route_opts
        end
      end
    end
  end

  @doc false
  def __options__(prefix, opts) do
    opts = Keyword.merge(@default_opts, opts)

    Enum.each(opts, &validate_opt!/1)

    session_args = [
      prefix,
      opts[:socket_path],
      opts[:transport]
    ]

    session_opts = [
      on_mount: [SquidSonarWeb.Hooks],
      session: {__MODULE__, :__session__, session_args},
      root_layout: {SquidSonarWeb.Layouts, :root}
    ]

    session_name = Keyword.get(opts, :as, :squid_sonar)

    {session_name, session_opts, as: session_name}
  end

  @doc false
  def __session__(_conn, prefix, live_path, live_transport) do
    %{
      "prefix" => prefix,
      "live_path" => live_path,
      "live_transport" => live_transport
    }
  end

  defp validate_opt!({:transport, transport}) do
    unless transport in @transport_values do
      raise ArgumentError, """
      invalid :transport, expected one of #{inspect(@transport_values)},
      got #{inspect(transport)}
      """
    end
  end

  defp validate_opt!({:socket_path, path}) do
    unless is_binary(path) and byte_size(path) > 0 do
      raise ArgumentError, """
      invalid :socket_path, expected a non-empty binary URL,
      got #{inspect(path)}
      """
    end
  end

  defp validate_opt!({:as, name}) do
    unless is_atom(name) do
      raise ArgumentError, """
      invalid :as, expected an atom route name,
      got #{inspect(name)}
      """
    end
  end

  defp validate_opt!(_option), do: :ok
end
