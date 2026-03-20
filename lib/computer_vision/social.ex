defmodule ComputerVision.Social do
  import Ecto.Query
  alias ComputerVision.Repo
  alias ComputerVision.Social.{Follow, Notification}

  def follow_user(follower_id, streamer_id) do
    %Follow{}
    |> Follow.changeset(%{follower_id: follower_id, streamer_id: streamer_id})
    |> Repo.insert()
  end

  def unfollow_user(follower_id, streamer_id) do
    from(f in Follow, where: f.follower_id == ^follower_id and f.streamer_id == ^streamer_id)
    |> Repo.delete_all()

    :ok
  end

  def following?(follower_id, streamer_id) do
    from(f in Follow, where: f.follower_id == ^follower_id and f.streamer_id == ^streamer_id)
    |> Repo.exists?()
  end

  def list_follower_ids(streamer_id) do
    from(f in Follow, where: f.streamer_id == ^streamer_id, select: f.follower_id)
    |> Repo.all()
  end

  def follower_count(streamer_id) do
    from(f in Follow, where: f.streamer_id == ^streamer_id)
    |> Repo.aggregate(:count)
  end

  def create_notification(attrs) do
    %Notification{}
    |> Notification.changeset(attrs)
    |> Repo.insert()
  end

  def list_unread_notifications(user_id) do
    from(n in Notification,
      where: n.user_id == ^user_id and is_nil(n.read_at),
      order_by: [desc: :inserted_at]
    )
    |> Repo.all()
  end

  def mark_notifications_read(user_id) do
    from(n in Notification, where: n.user_id == ^user_id and is_nil(n.read_at))
    |> Repo.update_all(set: [read_at: DateTime.utc_now()])
  end
end
