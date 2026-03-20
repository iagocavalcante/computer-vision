defmodule ComputerVision.Admin.InstanceSetting do
  use Ecto.Schema
  import Ecto.Changeset

  schema "instance_settings" do
    field :key, :string
    field :value, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(setting, attrs) do
    setting
    |> cast(attrs, [:key, :value])
    |> validate_required([:key])
    |> unique_constraint(:key)
  end
end
