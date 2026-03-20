defmodule ComputerVision.RTMPServer do
  @moduledoc "Manages the RTMP TCP server and spawns pipelines for incoming streams."
  use GenServer

  alias ComputerVision.LiveStream
  alias Membrane.RTMP.Source.TcpServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    port = Application.get_env(:computer_vision, :rtmp_port, 1935)
    host = Application.get_env(:computer_vision, :rtmp_host, {0, 0, 0, 0})

    tcp_server_options = %TcpServer{
      port: port,
      listen_options: [
        :binary,
        packet: :raw,
        active: false,
        ip: host
      ],
      socket_handler: fn socket ->
        {:ok, _sup, pid} =
          DynamicSupervisor.start_child(
            ComputerVision.PipelineSupervisor,
            {Membrane.Pipeline, {LiveStream, socket: socket}}
          )

        {:ok, pid}
      end
    }

    {:ok, pid} = TcpServer.start_link(tcp_server_options)
    {:ok, %{tcp_server: pid}}
  end
end
