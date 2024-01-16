defmodule ComputerVision.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  alias ComputerVision.LiveStream
  alias Membrane.RTMP.Source.TcpServer

  use Application

  @port Application.compile_env(:computer_vision, :stream_port, 1935)
  @host Application.compile_env(:computer_vision, :stream_host, {192, 168, 15, 9})

  @impl true
  def start(_type, _args) do
    File.mkdir_p("output")

    tcp_server_options = %TcpServer{
      port: @port,
      listen_options: [
        :binary,
        packet: :raw,
        active: false,
        ip: @host
      ],
      socket_handler: fn socket ->
        {:ok, _sup, pid} =
          Membrane.Pipeline.start_link(LiveStream, socket: socket)

        Agent.update(ComputerVision.SocketAgent, fn state ->
          Map.put(state, socket, %LiveStream{socket: socket})
        end)

        {:ok, pid}
      end
    }

    children = [
      %{id: TcpServer, start: {TcpServer, :start_link, [tcp_server_options]}},
      %{
        id: ComputerVision.SocketAgent,
        start: {Agent, :start_link, [fn -> %{} end, [name: ComputerVision.SocketAgent]]}
      },
      ComputerVisionWeb.Telemetry,
      ComputerVision.Repo,
      {DNSCluster, query: Application.get_env(:computer_vision, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ComputerVision.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: ComputerVision.Finch},
      # Start a worker by calling: ComputerVision.Worker.start_link(arg)
      # {ComputerVision.Worker, arg},
      # Start to serve requests, typically the last entry
      ComputerVisionWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ComputerVision.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ComputerVisionWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
