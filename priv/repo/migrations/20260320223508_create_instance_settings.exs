defmodule ComputerVision.Repo.Migrations.CreateInstanceSettings do
  use Ecto.Migration

  def change do
    create table(:instance_settings) do
      add :key, :string, null: false
      add :value, :string
      timestamps(type: :utc_datetime)
    end

    create unique_index(:instance_settings, [:key])
  end
end
