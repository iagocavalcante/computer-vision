defmodule ComputerVision.Social.Follow do
  use Ecto.Schema
  import Ecto.Changeset

  schema "follows" do
    belongs_to :follower, ComputerVision.Accounts.User
    belongs_to :streamer, ComputerVision.Accounts.User
    timestamps(type: :utc_datetime)
  end

  def changeset(follow, attrs) do
    follow
    |> cast(attrs, [:follower_id, :streamer_id])
    |> validate_required([:follower_id, :streamer_id])
    |> unique_constraint([:follower_id, :streamer_id])
    |> check_constraint(:follower_id, name: :no_self_follow, message: "cannot follow yourself")
    |> foreign_key_constraint(:follower_id)
    |> foreign_key_constraint(:streamer_id)
  end
end
