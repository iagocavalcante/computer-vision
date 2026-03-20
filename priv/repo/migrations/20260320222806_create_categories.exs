defmodule ComputerVision.Repo.Migrations.CreateCategories do
  use Ecto.Migration

  def change do
    create table(:categories) do
      add :name, :string, null: false
      add :slug, :string, null: false
      add :icon_url, :string
      add :parent_category_id, references(:categories, on_delete: :nilify_all)
      timestamps(type: :utc_datetime)
    end

    create unique_index(:categories, [:slug])

    alter table(:channels) do
      add :category_id, references(:categories, on_delete: :nilify_all)
    end
  end
end
