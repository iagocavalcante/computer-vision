defmodule ComputerVision.Repo.Migrations.CreateEmotesAndChatBans do
  use Ecto.Migration

  def change do
    create table(:emotes) do
      add :name, :string, null: false
      add :code, :string, null: false
      add :image_url, :string, null: false
      add :channel_id, references(:channels, on_delete: :delete_all)
      timestamps(type: :utc_datetime)
    end

    create unique_index(:emotes, [:channel_id, :code])

    create table(:chat_bans) do
      add :channel_id, references(:channels, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :reason, :string
      add :expires_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end

    create unique_index(:chat_bans, [:channel_id, :user_id])
  end
end
