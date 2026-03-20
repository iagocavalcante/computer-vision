defmodule ComputerVisionWeb.Admin.CategoriesLive do
  use ComputerVisionWeb, :live_view

  alias ComputerVision.Streaming
  alias ComputerVision.Streaming.Category

  @impl true
  def mount(_params, _session, socket) do
    categories = Streaming.list_categories()

    {:ok,
     assign(socket,
       categories: categories,
       category_form: to_form(Category.changeset(%Category{}, %{}), as: "category")
     )}
  end

  @impl true
  def handle_event("add_category", %{"category" => params}, socket) do
    case Streaming.create_category(params) do
      {:ok, _category} ->
        categories = Streaming.list_categories()

        {:noreply,
         socket
         |> assign(
           categories: categories,
           category_form: to_form(Category.changeset(%Category{}, %{}), as: "category")
         )
         |> put_flash(:info, "Category created")}

      {:error, changeset} ->
        {:noreply, assign(socket, category_form: to_form(changeset, as: "category"))}
    end
  end

  @impl true
  def handle_event("delete_category", %{"id" => id}, socket) do
    category = Streaming.get_category!(id)
    {:ok, _} = Streaming.delete_category(category)
    categories = Streaming.list_categories()

    {:noreply,
     socket
     |> assign(categories: categories)
     |> put_flash(:info, "Category deleted")}
  end
end
