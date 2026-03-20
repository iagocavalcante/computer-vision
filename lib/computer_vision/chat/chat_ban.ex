defmodule ComputerVision.Chat.ChatBan do
  use Ecto.Schema
  import Ecto.Changeset

  schema "chat_bans" do
    belongs_to :channel, ComputerVision.Streaming.Channel
    belongs_to :user, ComputerVision.Accounts.User
    field :reason, :string
    field :expires_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(chat_ban, attrs) do
    chat_ban
    |> cast(attrs, [:channel_id, :user_id, :reason, :expires_at])
    |> validate_required([:channel_id, :user_id])
    |> unique_constraint([:channel_id, :user_id])
    |> foreign_key_constraint(:channel_id)
    |> foreign_key_constraint(:user_id)
  end
end
