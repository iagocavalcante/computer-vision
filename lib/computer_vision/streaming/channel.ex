defmodule ComputerVision.Streaming.Channel do
  use Ecto.Schema
  import Ecto.Changeset
  alias ComputerVision.Accounts.User

  schema "channels" do
    belongs_to :user, User
    field :title, :string
    field :is_live, :boolean, default: false
    field :started_at, :utc_datetime
    field :viewer_count, :integer, default: 0
    field :thumbnail_url, :string
    field :transcoding_enabled, :boolean, default: false
    belongs_to :category, ComputerVision.Streaming.Category
    timestamps(type: :utc_datetime)
  end

  def changeset(channel, attrs) do
    channel
    |> cast(attrs, [
      :user_id,
      :title,
      :is_live,
      :started_at,
      :viewer_count,
      :thumbnail_url,
      :transcoding_enabled,
      :category_id
    ])
    |> validate_required([:user_id])
    |> unique_constraint(:user_id)
    |> foreign_key_constraint(:user_id)
  end

  def live_changeset(channel, is_live) do
    changes =
      if is_live,
        do: %{is_live: true, started_at: DateTime.utc_now() |> DateTime.truncate(:second)},
        else: %{is_live: false, started_at: nil}

    cast(channel, changes, [:is_live, :started_at])
  end
end
