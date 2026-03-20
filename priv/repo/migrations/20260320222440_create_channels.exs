defmodule ComputerVision.Repo.Migrations.CreateChannels do
  use Ecto.Migration

  def change do
    create table(:channels) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :title, :string
      add :is_live, :boolean, default: false, null: false
      add :started_at, :utc_datetime
      add :viewer_count, :integer, default: 0, null: false
      add :thumbnail_url, :string
      add :transcoding_enabled, :boolean, default: false, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:channels, [:user_id])
    create index(:channels, [:is_live])
  end
end
