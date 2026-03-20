defmodule ComputerVision.Streaming.Category do
  use Ecto.Schema
  import Ecto.Changeset

  schema "categories" do
    field :name, :string
    field :slug, :string
    field :icon_url, :string
    belongs_to :parent_category, __MODULE__
    has_many :subcategories, __MODULE__, foreign_key: :parent_category_id
    timestamps(type: :utc_datetime)
  end

  def changeset(category, attrs) do
    category
    |> cast(attrs, [:name, :slug, :icon_url, :parent_category_id])
    |> validate_required([:name, :slug])
    |> unique_constraint(:slug)
  end
end
