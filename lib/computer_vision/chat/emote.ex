defmodule ComputerVision.Chat.Emote do
  use Ecto.Schema
  import Ecto.Changeset

  schema "emotes" do
    field :name, :string
    field :code, :string
    field :image_url, :string
    belongs_to :channel, ComputerVision.Streaming.Channel

    timestamps(type: :utc_datetime)
  end

  def changeset(emote, attrs) do
    emote
    |> cast(attrs, [:name, :code, :image_url, :channel_id])
    |> validate_required([:name, :code, :image_url])
    |> unique_constraint([:channel_id, :code])
    |> foreign_key_constraint(:channel_id)
  end
end
