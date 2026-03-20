defmodule ComputerVision.Chat do
  import Ecto.Query
  alias ComputerVision.Repo
  alias ComputerVision.Chat.Emote
  alias ComputerVision.Chat.ChatBan

  def create_emote(attrs) do
    %Emote{}
    |> Emote.changeset(attrs)
    |> Repo.insert()
  end

  def list_emotes(channel_id) do
    from(e in Emote,
      where: is_nil(e.channel_id) or e.channel_id == ^channel_id
    )
    |> Repo.all()
  end

  def delete_emote(%Emote{} = emote) do
    Repo.delete(emote)
  end

  def ban_user(attrs) do
    %ChatBan{}
    |> ChatBan.changeset(attrs)
    |> Repo.insert()
  end

  def unban_user(channel_id, user_id) do
    from(b in ChatBan,
      where: b.channel_id == ^channel_id and b.user_id == ^user_id
    )
    |> Repo.delete_all()

    :ok
  end

  def banned?(channel_id, user_id) do
    now = DateTime.utc_now()

    from(b in ChatBan,
      where: b.channel_id == ^channel_id and b.user_id == ^user_id,
      where: is_nil(b.expires_at) or b.expires_at > ^now
    )
    |> Repo.exists?()
  end
end
