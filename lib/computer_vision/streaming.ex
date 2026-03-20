defmodule ComputerVision.Streaming do
  import Ecto.Query
  alias ComputerVision.Repo
  alias ComputerVision.Streaming.Channel

  def create_channel(attrs) do
    %Channel{}
    |> Channel.changeset(attrs)
    |> Repo.insert()
  end

  def get_channel_by_user(user_id) do
    Repo.get_by(Channel, user_id: user_id)
  end

  def set_channel_live(%Channel{} = channel, is_live) do
    channel
    |> Channel.live_changeset(is_live)
    |> Repo.update()
  end

  def list_live_channels do
    from(c in Channel,
      where: c.is_live == true,
      order_by: [desc: c.viewer_count],
      preload: [:user]
    )
    |> Repo.all()
  end

  def update_channel(%Channel{} = channel, attrs) do
    channel
    |> Channel.changeset(attrs)
    |> Repo.update()
  end
end
