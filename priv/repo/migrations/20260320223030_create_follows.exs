defmodule ComputerVision.Repo.Migrations.CreateFollows do
  use Ecto.Migration

  def change do
    create table(:follows) do
      add :follower_id, references(:users, on_delete: :delete_all), null: false
      add :streamer_id, references(:users, on_delete: :delete_all), null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:follows, [:follower_id, :streamer_id])
    create index(:follows, [:streamer_id])
    create constraint(:follows, :no_self_follow, check: "follower_id != streamer_id")
  end
end
