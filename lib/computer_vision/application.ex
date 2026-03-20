defmodule ComputerVision.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    File.mkdir_p("output")

    children =
      [
        ComputerVisionWeb.Telemetry,
        ComputerVision.Repo,
        {DNSCluster, query: Application.get_env(:computer_vision, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: ComputerVision.PubSub},
        {Finch, name: ComputerVision.Finch},
        ComputerVision.StreamRegistry,
        {DynamicSupervisor, name: ComputerVision.PipelineSupervisor, strategy: :one_for_one},
        rtmp_server_child(),
        ComputerVisionWeb.Presence,
        ComputerVision.NotificationWorker,
        ComputerVisionWeb.Endpoint
      ]
      |> Enum.reject(&is_nil/1)

    opts = [strategy: :one_for_one, name: ComputerVision.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp rtmp_server_child do
    if Application.get_env(:computer_vision, :start_rtmp_server, true) do
      ComputerVision.RTMPServer
    end
  end

  @impl true
  def config_change(changed, _new, removed) do
    ComputerVisionWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
