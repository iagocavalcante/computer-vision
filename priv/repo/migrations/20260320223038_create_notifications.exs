defmodule ComputerVision.Repo.Migrations.CreateNotifications do
  use Ecto.Migration

  def change do
    create table(:notifications) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :type, :string, null: false
      add :payload, :map, default: %{}
      add :read_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end

    create index(:notifications, [:user_id, :read_at])
  end
end
