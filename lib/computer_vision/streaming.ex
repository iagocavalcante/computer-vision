defmodule ComputerVision.Streaming do
  import Ecto.Query
  alias ComputerVision.Repo
  alias ComputerVision.Streaming.Channel
  alias ComputerVision.Streaming.Category

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
      preload: [:user, :category]
    )
    |> Repo.all()
  end

  def update_channel(%Channel{} = channel, attrs) do
    channel
    |> Channel.changeset(attrs)
    |> Repo.update()
  end

  def create_category(attrs) do
    %Category{} |> Category.changeset(attrs) |> Repo.insert()
  end

  def list_categories do
    Repo.all(Category)
  end

  def get_category!(id), do: Repo.get!(Category, id)

  def list_live_channels_by_category(category_id) do
    from(c in Channel,
      where: c.is_live == true and c.category_id == ^category_id,
      order_by: [desc: c.viewer_count],
      preload: [:user, :category]
    )
    |> Repo.all()
  end

  def search_live_channels(query) do
    search = "%#{query}%"

    from(c in Channel,
      join: u in assoc(c, :user),
      where: c.is_live == true,
      where: ilike(u.username, ^search) or ilike(c.title, ^search),
      order_by: [desc: c.viewer_count],
      preload: [:user, :category]
    )
    |> Repo.all()
  end
end
