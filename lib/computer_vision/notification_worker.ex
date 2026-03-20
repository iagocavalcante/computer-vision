defmodule ComputerVision.NotificationWorker do
  use GenServer

  alias ComputerVision.Social

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Phoenix.PubSub.subscribe(ComputerVision.PubSub, "streams")
    {:ok, %{}}
  end

  @impl true
  def handle_info({:streamer_went_live, user, channel}, state) do
    follower_ids = Social.list_follower_ids(user.id)

    Enum.each(follower_ids, fn follower_id ->
      Social.create_notification(%{
        user_id: follower_id,
        type: "streamer_went_live",
        payload: %{
          "username" => user.username,
          "channel_title" => channel.title,
          "channel_id" => channel.id
        }
      })

      Phoenix.PubSub.broadcast(
        ComputerVision.PubSub,
        "user:#{follower_id}",
        {:notification, :streamer_went_live, user}
      )
    end)

    {:noreply, state}
  end

  @impl true
  def handle_info(_, state), do: {:noreply, state}
end
