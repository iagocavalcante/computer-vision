defmodule ComputerVision.Social.Notification do
  use Ecto.Schema
  import Ecto.Changeset

  schema "notifications" do
    belongs_to :user, ComputerVision.Accounts.User
    field :type, :string
    field :payload, :map, default: %{}
    field :read_at, :utc_datetime
    timestamps(type: :utc_datetime)
  end

  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:user_id, :type, :payload, :read_at])
    |> validate_required([:user_id, :type])
    |> foreign_key_constraint(:user_id)
  end
end
