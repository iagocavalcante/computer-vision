# ComputerVision Streaming Platform — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Use elixir:ecto-thinking for all DB/schema work, elixir:phoenix-thinking for LiveView pages, elixir:otp-thinking for supervision/pipeline work.

**Goal:** Transform the prototype into a production-ready, self-hosted multi-tenant streaming platform with auth, live chat, viewer counts, categories, follows, emotes, and optional transcoding.

**Architecture:** Phoenix LiveView app with Membrane RTMP→HLS pipelines managed by DynamicSupervisor. Postgres for persistence, Redis-backed PubSub for multi-node chat/presence. Storage abstraction (local/S3). Docker Compose deployment.

**Tech Stack:** Phoenix 1.7, LiveView 0.20, Membrane Framework, Ecto/Postgres, Redis (Redix), Tailwind CSS, HLS.js

---

## Phase 1: Foundation

### Task 1: Add new dependencies to mix.exs

**Files:**
- Modify: `mix.exs`

**Step 1: Add dependencies**

Add to the `deps` function in `mix.exs`:

```elixir
# Rate limiting
{:hammer, "~> 6.1"},
# Redis for PubSub in production
{:redix, "~> 1.2"},
# S3 storage (optional)
{:ex_aws, "~> 2.4"},
{:ex_aws_s3, "~> 2.4"},
{:sweet_xml, "~> 0.7"},
# Node clustering
{:libcluster, "~> 3.3"},
# Image uploads
{:plug_multipart, "~> 0.3.0", only: :test}
```

**Step 2: Fetch deps**

Run: `mix deps.get`
Expected: All deps resolve without conflicts.

**Step 3: Commit**

```bash
git add mix.exs mix.lock
git commit -m "chore: add hammer, redix, ex_aws, libcluster dependencies"
```

---

### Task 2: Generate authentication with phx.gen.auth

**Files:**
- Create: Multiple files via generator
- Modify: `lib/computer_vision_web/router.ex`

**Step 1: Run the auth generator**

Run: `mix phx.gen.auth Accounts User users`
Expected: Generates user schema, migration, LiveView auth pages, plugs.

**Step 2: Review and customize the generated migration**

Open the generated migration in `priv/repo/migrations/*_create_users_auth_tables.exs` and add these fields to the `users` table:

```elixir
add :username, :string, null: false
add :display_name, :string
add :avatar_url, :string
add :bio, :text
add :stream_key, :uuid, default: fragment("gen_random_uuid()"), null: false
add :role, :string, default: "streamer", null: false
```

Add indexes:

```elixir
create unique_index(:users, [:username])
create unique_index(:users, [:stream_key])
```

**Step 3: Update the User schema**

Modify `lib/computer_vision/accounts/user.ex` to add the new fields:

```elixir
field :username, :string
field :display_name, :string
field :avatar_url, :string
field :bio, :string
field :stream_key, Ecto.UUID, autogenerate: true
field :role, :string, default: "streamer"
```

Add a `registration_changeset` validation for username:

```elixir
|> validate_required([:username])
|> validate_length(:username, min: 3, max: 30)
|> validate_format(:username, ~r/^[a-zA-Z0-9_]+$/, message: "only letters, numbers, and underscores")
|> unique_constraint(:username)
```

Add a `stream_key_changeset`:

```elixir
def stream_key_changeset(user) do
  change(user, stream_key: Ecto.UUID.generate())
end
```

**Step 4: Run migration**

Run: `mix ecto.migrate`
Expected: Migration succeeds.

**Step 5: Run generated tests**

Run: `mix test test/computer_vision/accounts_test.exs`
Expected: Tests pass (may need adjustments for new required fields).

**Step 6: Commit**

```bash
git add -A
git commit -m "feat: add user authentication with phx.gen.auth and custom fields"
```

---

### Task 3: Create channels schema and migration

**Files:**
- Create: `priv/repo/migrations/*_create_channels.exs`
- Create: `lib/computer_vision/streaming/channel.ex`
- Create: `lib/computer_vision/streaming.ex`

**Step 1: Write the failing test**

Create `test/computer_vision/streaming_test.exs`:

```elixir
defmodule ComputerVision.StreamingTest do
  use ComputerVision.DataCase

  alias ComputerVision.Streaming
  alias ComputerVision.Streaming.Channel

  describe "channels" do
    setup do
      user = insert_user()
      %{user: user}
    end

    test "create_channel/1 creates a channel for a user", %{user: user} do
      assert {:ok, %Channel{} = channel} =
               Streaming.create_channel(%{user_id: user.id, title: "My Stream"})

      assert channel.user_id == user.id
      assert channel.title == "My Stream"
      assert channel.is_live == false
    end

    test "get_channel_by_user/1 returns the channel", %{user: user} do
      {:ok, channel} = Streaming.create_channel(%{user_id: user.id})
      assert Streaming.get_channel_by_user(user.id).id == channel.id
    end

    test "set_channel_live/2 marks channel as live", %{user: user} do
      {:ok, channel} = Streaming.create_channel(%{user_id: user.id})
      {:ok, updated} = Streaming.set_channel_live(channel, true)
      assert updated.is_live == true
      assert updated.started_at != nil
    end
  end

  defp insert_user do
    {:ok, user} =
      ComputerVision.Accounts.register_user(%{
        email: "test@example.com",
        username: "testuser",
        password: "validpassword123"
      })

    user
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/computer_vision/streaming_test.exs`
Expected: FAIL — module `Streaming` not found.

**Step 3: Generate migration**

Run: `mix ecto.gen.migration create_channels`

Write the migration:

```elixir
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
```

**Step 4: Create the Channel schema**

Create `lib/computer_vision/streaming/channel.ex`:

```elixir
defmodule ComputerVision.Streaming.Channel do
  use Ecto.Schema
  import Ecto.Changeset

  alias ComputerVision.Accounts.User

  schema "channels" do
    belongs_to :user, User
    field :title, :string
    field :is_live, :boolean, default: false
    field :started_at, :utc_datetime
    field :viewer_count, :integer, default: 0
    field :thumbnail_url, :string
    field :transcoding_enabled, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  def changeset(channel, attrs) do
    channel
    |> cast(attrs, [:user_id, :title, :is_live, :started_at, :viewer_count, :thumbnail_url, :transcoding_enabled])
    |> validate_required([:user_id])
    |> unique_constraint(:user_id)
    |> foreign_key_constraint(:user_id)
  end

  def live_changeset(channel, is_live) do
    changes = if is_live, do: %{is_live: true, started_at: DateTime.utc_now()}, else: %{is_live: false, started_at: nil}
    cast(channel, changes, [:is_live, :started_at])
  end
end
```

**Step 5: Create the Streaming context**

Create `lib/computer_vision/streaming.ex`:

```elixir
defmodule ComputerVision.Streaming do
  import Ecto.Query
  alias ComputerVision.Repo
  alias ComputerVision.Streaming.Channel

  def create_channel(attrs) do
    %Channel{}
    |> Channel.changeset(attrs)
    |> Repo.insert()
  end

  def get_channel_by_user(user_id) do
    Repo.get_by(Channel, user_id: user_id)
  end

  def set_channel_live(%Channel{} = channel, is_live) do
    channel
    |> Channel.live_changeset(is_live)
    |> Repo.update()
  end

  def list_live_channels do
    from(c in Channel,
      where: c.is_live == true,
      order_by: [desc: c.viewer_count],
      preload: [:user]
    )
    |> Repo.all()
  end
end
```

**Step 6: Run migration and tests**

Run: `mix ecto.migrate && mix test test/computer_vision/streaming_test.exs`
Expected: PASS

**Step 7: Commit**

```bash
git add -A
git commit -m "feat: add channels schema, migration, and streaming context"
```

---

### Task 4: Create categories schema and migration

**Files:**
- Create: `priv/repo/migrations/*_create_categories.exs`
- Create: `lib/computer_vision/streaming/category.ex`
- Modify: `lib/computer_vision/streaming.ex`
- Modify: `lib/computer_vision/streaming/channel.ex`

**Step 1: Write the failing test**

Add to `test/computer_vision/streaming_test.exs`:

```elixir
describe "categories" do
  test "create_category/1 creates a category" do
    assert {:ok, category} =
             Streaming.create_category(%{name: "Gaming", slug: "gaming"})

    assert category.name == "Gaming"
    assert category.slug == "gaming"
  end

  test "list_categories/0 returns all categories" do
    {:ok, _} = Streaming.create_category(%{name: "Gaming", slug: "gaming"})
    {:ok, _} = Streaming.create_category(%{name: "Music", slug: "music"})
    assert length(Streaming.list_categories()) == 2
  end

  test "channels can belong to a category", %{user: user} do
    {:ok, category} = Streaming.create_category(%{name: "Gaming", slug: "gaming"})

    {:ok, channel} =
      Streaming.create_channel(%{user_id: user.id, title: "My Stream", category_id: category.id})

    assert channel.category_id == category.id
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/computer_vision/streaming_test.exs`
Expected: FAIL

**Step 3: Generate migration**

Run: `mix ecto.gen.migration create_categories`

```elixir
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
```

**Step 4: Create Category schema**

Create `lib/computer_vision/streaming/category.ex`:

```elixir
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
```

**Step 5: Update Channel schema to add category association**

Add to `lib/computer_vision/streaming/channel.ex`:

```elixir
belongs_to :category, ComputerVision.Streaming.Category
```

Update `changeset` to include `:category_id` in cast fields.

**Step 6: Add context functions to `lib/computer_vision/streaming.ex`**

```elixir
alias ComputerVision.Streaming.Category

def create_category(attrs) do
  %Category{}
  |> Category.changeset(attrs)
  |> Repo.insert()
end

def list_categories do
  Repo.all(Category)
end

def get_category!(id), do: Repo.get!(Category, id)
```

**Step 7: Run migration and tests**

Run: `mix ecto.migrate && mix test test/computer_vision/streaming_test.exs`
Expected: PASS

**Step 8: Commit**

```bash
git add -A
git commit -m "feat: add categories schema with subcategory support"
```

---

### Task 5: Create follows and notifications schemas

**Files:**
- Create: `priv/repo/migrations/*_create_follows.exs`
- Create: `priv/repo/migrations/*_create_notifications.exs`
- Create: `lib/computer_vision/social/follow.ex`
- Create: `lib/computer_vision/social/notification.ex`
- Create: `lib/computer_vision/social.ex`

**Step 1: Write the failing test**

Create `test/computer_vision/social_test.exs`:

```elixir
defmodule ComputerVision.SocialTest do
  use ComputerVision.DataCase

  alias ComputerVision.Social

  setup do
    {:ok, follower} =
      ComputerVision.Accounts.register_user(%{
        email: "follower@example.com",
        username: "follower",
        password: "validpassword123"
      })

    {:ok, streamer} =
      ComputerVision.Accounts.register_user(%{
        email: "streamer@example.com",
        username: "streamer",
        password: "validpassword123"
      })

    %{follower: follower, streamer: streamer}
  end

  test "follow_user/2 creates a follow", %{follower: follower, streamer: streamer} do
    assert {:ok, follow} = Social.follow_user(follower.id, streamer.id)
    assert follow.follower_id == follower.id
    assert follow.streamer_id == streamer.id
  end

  test "follow_user/2 prevents self-follow", %{follower: follower} do
    assert {:error, _} = Social.follow_user(follower.id, follower.id)
  end

  test "unfollow_user/2 removes a follow", %{follower: follower, streamer: streamer} do
    {:ok, _} = Social.follow_user(follower.id, streamer.id)
    assert :ok = Social.unfollow_user(follower.id, streamer.id)
    assert Social.following?(follower.id, streamer.id) == false
  end

  test "list_followers/1 returns follower ids", %{follower: follower, streamer: streamer} do
    {:ok, _} = Social.follow_user(follower.id, streamer.id)
    followers = Social.list_follower_ids(streamer.id)
    assert follower.id in followers
  end

  test "create_notification/1 and list_unread/1", %{follower: follower} do
    {:ok, notif} =
      Social.create_notification(%{
        user_id: follower.id,
        type: "streamer_went_live",
        payload: %{"username" => "streamer"}
      })

    unread = Social.list_unread_notifications(follower.id)
    assert length(unread) == 1
    assert hd(unread).id == notif.id
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/computer_vision/social_test.exs`
Expected: FAIL

**Step 3: Create migrations**

Run: `mix ecto.gen.migration create_follows && mix ecto.gen.migration create_notifications`

Follows migration:

```elixir
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
```

Notifications migration:

```elixir
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
```

**Step 4: Create schemas and context**

Create `lib/computer_vision/social/follow.ex`:

```elixir
defmodule ComputerVision.Social.Follow do
  use Ecto.Schema
  import Ecto.Changeset

  schema "follows" do
    belongs_to :follower, ComputerVision.Accounts.User
    belongs_to :streamer, ComputerVision.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(follow, attrs) do
    follow
    |> cast(attrs, [:follower_id, :streamer_id])
    |> validate_required([:follower_id, :streamer_id])
    |> unique_constraint([:follower_id, :streamer_id])
    |> check_constraint(:follower_id, name: :no_self_follow, message: "cannot follow yourself")
    |> foreign_key_constraint(:follower_id)
    |> foreign_key_constraint(:streamer_id)
  end
end
```

Create `lib/computer_vision/social/notification.ex`:

```elixir
defmodule ComputerVision.Social.Notification do
  use Ecto.Schema
  import Ecto.Changeset

  schema "notifications" do
    belongs_to :user, ComputerVision.Accounts.User
    field :type, :string
    field :payload, :map, default: %{}
    field :read_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:user_id, :type, :payload, :read_at])
    |> validate_required([:user_id, :type])
    |> foreign_key_constraint(:user_id)
  end
end
```

Create `lib/computer_vision/social.ex`:

```elixir
defmodule ComputerVision.Social do
  import Ecto.Query
  alias ComputerVision.Repo
  alias ComputerVision.Social.{Follow, Notification}

  def follow_user(follower_id, streamer_id) do
    %Follow{}
    |> Follow.changeset(%{follower_id: follower_id, streamer_id: streamer_id})
    |> Repo.insert()
  end

  def unfollow_user(follower_id, streamer_id) do
    from(f in Follow, where: f.follower_id == ^follower_id and f.streamer_id == ^streamer_id)
    |> Repo.delete_all()

    :ok
  end

  def following?(follower_id, streamer_id) do
    from(f in Follow, where: f.follower_id == ^follower_id and f.streamer_id == ^streamer_id)
    |> Repo.exists?()
  end

  def list_follower_ids(streamer_id) do
    from(f in Follow, where: f.streamer_id == ^streamer_id, select: f.follower_id)
    |> Repo.all()
  end

  def follower_count(streamer_id) do
    from(f in Follow, where: f.streamer_id == ^streamer_id)
    |> Repo.aggregate(:count)
  end

  def create_notification(attrs) do
    %Notification{}
    |> Notification.changeset(attrs)
    |> Repo.insert()
  end

  def list_unread_notifications(user_id) do
    from(n in Notification,
      where: n.user_id == ^user_id and is_nil(n.read_at),
      order_by: [desc: :inserted_at]
    )
    |> Repo.all()
  end

  def mark_notifications_read(user_id) do
    from(n in Notification, where: n.user_id == ^user_id and is_nil(n.read_at))
    |> Repo.update_all(set: [read_at: DateTime.utc_now()])
  end
end
```

**Step 5: Run migration and tests**

Run: `mix ecto.migrate && mix test test/computer_vision/social_test.exs`
Expected: PASS

**Step 6: Commit**

```bash
git add -A
git commit -m "feat: add follows and notifications with social context"
```

---

### Task 6: Create emotes and chat_bans schemas

**Files:**
- Create: `priv/repo/migrations/*_create_emotes_and_chat_bans.exs`
- Create: `lib/computer_vision/chat/emote.ex`
- Create: `lib/computer_vision/chat/chat_ban.ex`
- Create: `lib/computer_vision/chat.ex`

**Step 1: Write the failing test**

Create `test/computer_vision/chat_test.exs`:

```elixir
defmodule ComputerVision.ChatTest do
  use ComputerVision.DataCase

  alias ComputerVision.Chat

  setup do
    {:ok, user} =
      ComputerVision.Accounts.register_user(%{
        email: "test@example.com",
        username: "testuser",
        password: "validpassword123"
      })

    {:ok, channel} =
      ComputerVision.Streaming.create_channel(%{user_id: user.id})

    %{user: user, channel: channel}
  end

  test "create_emote/1 creates a channel emote", %{channel: channel} do
    assert {:ok, emote} =
             Chat.create_emote(%{
               name: "Hype",
               code: ":hype:",
               image_url: "/emotes/hype.png",
               channel_id: channel.id
             })

    assert emote.code == ":hype:"
  end

  test "list_emotes/1 returns channel + global emotes", %{channel: channel} do
    {:ok, _} = Chat.create_emote(%{name: "Global", code: ":global:", image_url: "/g.png"})

    {:ok, _} =
      Chat.create_emote(%{
        name: "Local",
        code: ":local:",
        image_url: "/l.png",
        channel_id: channel.id
      })

    emotes = Chat.list_emotes(channel.id)
    assert length(emotes) == 2
  end

  test "ban_user/1 and banned?/2", %{user: user, channel: channel} do
    {:ok, _} = Chat.ban_user(%{channel_id: channel.id, user_id: user.id, reason: "spam"})
    assert Chat.banned?(channel.id, user.id) == true
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/computer_vision/chat_test.exs`
Expected: FAIL

**Step 3: Create migration**

Run: `mix ecto.gen.migration create_emotes_and_chat_bans`

```elixir
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
```

**Step 4: Create schemas and context**

Create `lib/computer_vision/chat/emote.ex`:

```elixir
defmodule ComputerVision.Chat.Emote do
  use Ecto.Schema
  import Ecto.Changeset

  schema "emotes" do
    field :name, :string
    field :code, :string
    field :image_url, :string
    belongs_to :channel, ComputerVision.Streaming.Channel

    timestamps(type: :utc_datetime)
  end

  def changeset(emote, attrs) do
    emote
    |> cast(attrs, [:name, :code, :image_url, :channel_id])
    |> validate_required([:name, :code, :image_url])
    |> unique_constraint([:channel_id, :code])
  end
end
```

Create `lib/computer_vision/chat/chat_ban.ex`:

```elixir
defmodule ComputerVision.Chat.ChatBan do
  use Ecto.Schema
  import Ecto.Changeset

  schema "chat_bans" do
    belongs_to :channel, ComputerVision.Streaming.Channel
    belongs_to :user, ComputerVision.Accounts.User
    field :reason, :string
    field :expires_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(ban, attrs) do
    ban
    |> cast(attrs, [:channel_id, :user_id, :reason, :expires_at])
    |> validate_required([:channel_id, :user_id])
    |> unique_constraint([:channel_id, :user_id])
    |> foreign_key_constraint(:channel_id)
    |> foreign_key_constraint(:user_id)
  end
end
```

Create `lib/computer_vision/chat.ex`:

```elixir
defmodule ComputerVision.Chat do
  import Ecto.Query
  alias ComputerVision.Repo
  alias ComputerVision.Chat.{Emote, ChatBan}

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

  def delete_emote(emote_id) do
    Repo.get!(Emote, emote_id) |> Repo.delete()
  end

  def ban_user(attrs) do
    %ChatBan{}
    |> ChatBan.changeset(attrs)
    |> Repo.insert()
  end

  def unban_user(channel_id, user_id) do
    from(b in ChatBan, where: b.channel_id == ^channel_id and b.user_id == ^user_id)
    |> Repo.delete_all()

    :ok
  end

  def banned?(channel_id, user_id) do
    from(b in ChatBan,
      where: b.channel_id == ^channel_id and b.user_id == ^user_id,
      where: is_nil(b.expires_at) or b.expires_at > ^DateTime.utc_now()
    )
    |> Repo.exists?()
  end
end
```

**Step 5: Run migration and tests**

Run: `mix ecto.migrate && mix test test/computer_vision/chat_test.exs`
Expected: PASS

**Step 6: Commit**

```bash
git add -A
git commit -m "feat: add emotes and chat bans schemas with chat context"
```

---

### Task 7: Create instance_settings schema

**Files:**
- Create: `priv/repo/migrations/*_create_instance_settings.exs`
- Create: `lib/computer_vision/admin/instance_setting.ex`
- Create: `lib/computer_vision/admin.ex`

**Step 1: Write the failing test**

Create `test/computer_vision/admin_test.exs`:

```elixir
defmodule ComputerVision.AdminTest do
  use ComputerVision.DataCase

  alias ComputerVision.Admin

  test "set/2 and get/2 for instance settings" do
    Admin.set("site_name", "My Stream Site")
    assert Admin.get("site_name") == "My Stream Site"
  end

  test "get/2 returns default when not set" do
    assert Admin.get("missing_key", "default") == "default"
  end

  test "set/2 updates existing key" do
    Admin.set("site_name", "Old Name")
    Admin.set("site_name", "New Name")
    assert Admin.get("site_name") == "New Name"
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/computer_vision/admin_test.exs`
Expected: FAIL

**Step 3: Create migration, schema, and context**

Run: `mix ecto.gen.migration create_instance_settings`

```elixir
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
```

Create `lib/computer_vision/admin/instance_setting.ex`:

```elixir
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
```

Create `lib/computer_vision/admin.ex`:

```elixir
defmodule ComputerVision.Admin do
  alias ComputerVision.Repo
  alias ComputerVision.Admin.InstanceSetting

  def get(key, default \\ nil) do
    case Repo.get_by(InstanceSetting, key: key) do
      nil -> default
      setting -> setting.value
    end
  end

  def set(key, value) do
    case Repo.get_by(InstanceSetting, key: key) do
      nil ->
        %InstanceSetting{}
        |> InstanceSetting.changeset(%{key: key, value: value})
        |> Repo.insert()

      setting ->
        setting
        |> InstanceSetting.changeset(%{value: value})
        |> Repo.update()
    end
  end
end
```

**Step 4: Run migration and tests**

Run: `mix ecto.migrate && mix test test/computer_vision/admin_test.exs`
Expected: PASS

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: add instance settings key-value store for admin config"
```

---

## Phase 2: Core Streaming Infrastructure

### Task 8: Refactor supervision tree with DynamicSupervisor

**Files:**
- Modify: `lib/computer_vision/application.ex`
- Create: `lib/computer_vision/stream_registry.ex`
- Modify: `config/runtime.exs`

**Step 1: Write the test**

Create `test/computer_vision/stream_registry_test.exs`:

```elixir
defmodule ComputerVision.StreamRegistryTest do
  use ComputerVision.DataCase

  alias ComputerVision.StreamRegistry

  test "register/2 and lookup/1" do
    StreamRegistry.register("channel_1", self())
    assert {:ok, pid} = StreamRegistry.lookup("channel_1")
    assert pid == self()
  end

  test "lookup/1 returns error for unknown channel" do
    assert :error = StreamRegistry.lookup("unknown")
  end

  test "unregister/1 removes entry" do
    StreamRegistry.register("channel_2", self())
    StreamRegistry.unregister("channel_2")
    assert :error = StreamRegistry.lookup("channel_2")
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/computer_vision/stream_registry_test.exs`
Expected: FAIL

**Step 3: Create StreamRegistry**

Create `lib/computer_vision/stream_registry.ex`:

```elixir
defmodule ComputerVision.StreamRegistry do
  @moduledoc """
  Registry for active stream pipelines. Maps channel identifiers to pipeline PIDs.
  """

  def child_spec(_opts) do
    Registry.child_spec(keys: :unique, name: __MODULE__)
  end

  def register(channel_id, pid \\ self()) do
    Registry.register(__MODULE__, channel_id, pid)
  end

  def unregister(channel_id) do
    Registry.unregister(__MODULE__, channel_id)
  end

  def lookup(channel_id) do
    case Registry.lookup(__MODULE__, channel_id) do
      [{pid, _}] -> {:ok, pid}
      [] -> :error
    end
  end
end
```

**Step 4: Update application.ex**

Rewrite `lib/computer_vision/application.ex`:

```elixir
defmodule ComputerVision.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    File.mkdir_p("output")

    children = [
      ComputerVisionWeb.Telemetry,
      ComputerVision.Repo,
      {DNSCluster, query: Application.get_env(:computer_vision, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ComputerVision.PubSub},
      {Finch, name: ComputerVision.Finch},
      ComputerVision.StreamRegistry,
      {DynamicSupervisor, name: ComputerVision.PipelineSupervisor, strategy: :one_for_one},
      ComputerVision.RTMPServer,
      ComputerVisionWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: ComputerVision.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    ComputerVisionWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
```

**Step 5: Create RTMPServer GenServer**

Create `lib/computer_vision/rtmp_server.ex`:

```elixir
defmodule ComputerVision.RTMPServer do
  @moduledoc """
  Manages the RTMP TCP server and spawns pipelines for incoming streams.
  """
  use GenServer

  alias ComputerVision.LiveStream
  alias Membrane.RTMP.Source.TcpServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    port = Application.get_env(:computer_vision, :rtmp_port, 1935)
    host = Application.get_env(:computer_vision, :rtmp_host, {0, 0, 0, 0})

    tcp_server_options = %TcpServer{
      port: port,
      listen_options: [
        :binary,
        packet: :raw,
        active: false,
        ip: host
      ],
      socket_handler: fn socket ->
        {:ok, _sup, pid} =
          DynamicSupervisor.start_child(
            ComputerVision.PipelineSupervisor,
            {Membrane.Pipeline, {LiveStream, socket: socket}}
          )

        {:ok, pid}
      end
    }

    {:ok, pid} = TcpServer.start_link(tcp_server_options)
    {:ok, %{tcp_server: pid}}
  end
end
```

**Step 6: Move RTMP config to runtime.exs**

Add to `config/runtime.exs`:

```elixir
config :computer_vision,
  rtmp_port: String.to_integer(System.get_env("RTMP_PORT", "1935")),
  rtmp_host: {0, 0, 0, 0}
```

**Step 7: Run tests**

Run: `mix test test/computer_vision/stream_registry_test.exs`
Expected: PASS

**Step 8: Commit**

```bash
git add -A
git commit -m "refactor: add DynamicSupervisor, StreamRegistry, and RTMPServer GenServer"
```

---

### Task 9: Create storage abstraction layer

**Files:**
- Create: `lib/computer_vision/storage.ex`
- Create: `lib/computer_vision/storage/local.ex`
- Create: `lib/computer_vision/storage/s3.ex`

**Step 1: Write the failing test**

Create `test/computer_vision/storage/local_test.exs`:

```elixir
defmodule ComputerVision.Storage.LocalTest do
  use ExUnit.Case, async: true

  alias ComputerVision.Storage.Local

  @test_dir "test/tmp/storage"

  setup do
    File.rm_rf!(@test_dir)
    File.mkdir_p!(@test_dir)
    on_exit(fn -> File.rm_rf!(@test_dir) end)
    %{base_dir: @test_dir}
  end

  test "write and read segment", %{base_dir: base_dir} do
    assert :ok = Local.write_segment(base_dir, "user1", "stream1", "seg0.ts", "video data")
    assert {:ok, "video data"} = Local.read_segment(base_dir, "user1", "stream1", "seg0.ts")
  end

  test "read non-existent segment returns error", %{base_dir: base_dir} do
    assert {:error, :enoent} = Local.read_segment(base_dir, "user1", "stream1", "missing.ts")
  end

  test "delete_stream removes all segments", %{base_dir: base_dir} do
    Local.write_segment(base_dir, "user1", "stream1", "seg0.ts", "data")
    Local.write_segment(base_dir, "user1", "stream1", "seg1.ts", "data")
    assert :ok = Local.delete_stream(base_dir, "user1", "stream1")
    assert {:error, :enoent} = Local.read_segment(base_dir, "user1", "stream1", "seg0.ts")
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/computer_vision/storage/local_test.exs`
Expected: FAIL

**Step 3: Create storage behaviour and local implementation**

Create `lib/computer_vision/storage.ex`:

```elixir
defmodule ComputerVision.Storage do
  @moduledoc """
  Storage abstraction for HLS segments. Supports local filesystem and S3.
  """

  @callback write_segment(String.t(), String.t(), String.t(), binary()) :: :ok | {:error, term()}
  @callback read_segment(String.t(), String.t(), String.t()) :: {:ok, binary()} | {:error, term()}
  @callback delete_stream(String.t(), String.t()) :: :ok | {:error, term()}

  def impl do
    Application.get_env(:computer_vision, :storage_backend, ComputerVision.Storage.Local)
  end

  def base_dir do
    Application.get_env(:computer_vision, :storage_dir, "output")
  end
end
```

Create `lib/computer_vision/storage/local.ex`:

```elixir
defmodule ComputerVision.Storage.Local do
  @behaviour ComputerVision.Storage

  def write_segment(base_dir, user_id, stream_id, filename, data) do
    path = build_path(base_dir, user_id, stream_id, filename)
    File.mkdir_p!(Path.dirname(path))
    File.write(path, data)
  end

  def read_segment(base_dir, user_id, stream_id, filename) do
    path = build_path(base_dir, user_id, stream_id, filename)
    File.read(path)
  end

  def delete_stream(base_dir, user_id, stream_id) do
    path = Path.join([base_dir, user_id, stream_id])

    case File.rm_rf(path) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_path(base_dir, user_id, stream_id, filename) do
    Path.join([base_dir, user_id, stream_id, filename])
  end
end
```

Create `lib/computer_vision/storage/s3.ex` (stub for now):

```elixir
defmodule ComputerVision.Storage.S3 do
  @behaviour ComputerVision.Storage

  def write_segment(_base_dir, user_id, stream_id, filename, data) do
    bucket = Application.get_env(:computer_vision, :s3_bucket)
    key = "streams/#{user_id}/#{stream_id}/#{filename}"

    case ExAws.S3.put_object(bucket, key, data) |> ExAws.request() do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  def read_segment(_base_dir, user_id, stream_id, filename) do
    bucket = Application.get_env(:computer_vision, :s3_bucket)
    key = "streams/#{user_id}/#{stream_id}/#{filename}"

    case ExAws.S3.get_object(bucket, key) |> ExAws.request() do
      {:ok, %{body: body}} -> {:ok, body}
      {:error, reason} -> {:error, reason}
    end
  end

  def delete_stream(_base_dir, user_id, stream_id) do
    bucket = Application.get_env(:computer_vision, :s3_bucket)
    prefix = "streams/#{user_id}/#{stream_id}/"

    ExAws.S3.list_objects(bucket, prefix: prefix)
    |> ExAws.stream!()
    |> Enum.each(fn %{key: key} ->
      ExAws.S3.delete_object(bucket, key) |> ExAws.request()
    end)

    :ok
  end
end
```

**Step 4: Run tests**

Run: `mix test test/computer_vision/storage/local_test.exs`
Expected: PASS

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: add storage abstraction layer with local and S3 backends"
```

---

### Task 10: Update RTMP validator to use real DB auth

**Files:**
- Modify: `lib/computer_vision/validator.ex`
- Create: `test/computer_vision/validator_test.exs`

**Step 1: Write the failing test**

Create `test/computer_vision/validator_test.exs`:

```elixir
defmodule ComputerVision.ValidatorTest do
  use ComputerVision.DataCase

  alias ComputerVision.Accounts

  test "validates correct stream key format" do
    {:ok, user} =
      Accounts.register_user(%{
        email: "test@example.com",
        username: "teststreamer",
        password: "validpassword123"
      })

    stream_key = "teststreamer_#{user.stream_key}"
    assert {:ok, _} = ComputerVision.Validator.validate_stream_key(stream_key)
  end

  test "rejects invalid stream key" do
    assert {:error, _} = ComputerVision.Validator.validate_stream_key("baduser_invalidkey")
  end

  test "rejects non-existent user" do
    assert {:error, _} =
             ComputerVision.Validator.validate_stream_key(
               "nouser_#{Ecto.UUID.generate()}"
             )
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/computer_vision/validator_test.exs`
Expected: FAIL

**Step 3: Rewrite the Validator**

Rewrite `lib/computer_vision/validator.ex`:

```elixir
defmodule ComputerVision.Validator do
  @enforce_keys [:socket]
  defstruct @enforce_keys

  alias ComputerVision.Accounts
  alias ComputerVision.Streaming

  def validate_stream_key(full_key) do
    case String.split(full_key, "_", parts: 2) do
      [username, stream_key] ->
        case Accounts.get_user_by_username(username) do
          nil ->
            {:error, "user not found"}

          user ->
            if user.stream_key == stream_key do
              ensure_channel(user)
              {:ok, user}
            else
              {:error, "invalid stream key"}
            end
        end

      _ ->
        {:error, "malformed stream key"}
    end
  end

  defp ensure_channel(user) do
    case Streaming.get_channel_by_user(user.id) do
      nil -> Streaming.create_channel(%{user_id: user.id})
      channel -> {:ok, channel}
    end
  end
end

defimpl Membrane.RTMP.MessageValidator, for: ComputerVision.Validator do
  @impl true
  def validate_release_stream(_impl, _message) do
    {:ok, "stream released"}
  end

  @impl true
  def validate_publish(_impl, message) do
    case ComputerVision.Validator.validate_stream_key(message.stream_key) do
      {:ok, user} ->
        channel = ComputerVision.Streaming.get_channel_by_user(user.id)
        ComputerVision.Streaming.set_channel_live(channel, true)

        Phoenix.PubSub.broadcast(
          ComputerVision.PubSub,
          "streams",
          {:streamer_went_live, user, channel}
        )

        {:ok, "publish stream successful"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def validate_set_data_frame(_impl, _message) do
    {:ok, "set data frame successful"}
  end
end
```

**Step 4: Add `get_user_by_username` to Accounts context**

Add to `lib/computer_vision/accounts.ex`:

```elixir
def get_user_by_username(username) do
  Repo.get_by(User, username: username)
end
```

**Step 5: Run tests**

Run: `mix test test/computer_vision/validator_test.exs`
Expected: PASS

**Step 6: Commit**

```bash
git add -A
git commit -m "feat: validate RTMP stream keys against user database"
```

---

## Phase 3: LiveView UI

### Task 11: Create Phoenix Presence module

**Files:**
- Create: `lib/computer_vision_web/presence.ex`

**Step 1: Create Presence module**

```elixir
defmodule ComputerVisionWeb.Presence do
  use Phoenix.Presence,
    otp_app: :computer_vision,
    pubsub_server: ComputerVision.PubSub
end
```

**Step 2: Add to supervision tree**

Add `ComputerVisionWeb.Presence` to the children list in `application.ex`, before the Endpoint.

**Step 3: Commit**

```bash
git add -A
git commit -m "feat: add Phoenix Presence for viewer tracking"
```

---

### Task 12: Build homepage/directory LiveView

**Files:**
- Create: `lib/computer_vision_web/live/directory_live.ex`
- Create: `lib/computer_vision_web/live/directory_live.html.heex`
- Modify: `lib/computer_vision_web/router.ex`

**Step 1: Create the LiveView**

Create `lib/computer_vision_web/live/directory_live.ex`:

```elixir
defmodule ComputerVisionWeb.DirectoryLive do
  use ComputerVisionWeb, :live_view

  alias ComputerVision.Streaming

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(ComputerVision.PubSub, "streams")
    end

    channels = Streaming.list_live_channels()
    categories = Streaming.list_categories()

    {:ok,
     assign(socket,
       channels: channels,
       categories: categories,
       selected_category: nil,
       search_query: ""
     )}
  end

  @impl true
  def handle_info({:streamer_went_live, _user, _channel}, socket) do
    channels = Streaming.list_live_channels()
    {:noreply, assign(socket, channels: channels)}
  end

  @impl true
  def handle_info({:stream_ended, _channel_id}, socket) do
    channels = Streaming.list_live_channels()
    {:noreply, assign(socket, channels: channels)}
  end

  @impl true
  def handle_event("filter_category", %{"category_id" => ""}, socket) do
    channels = Streaming.list_live_channels()
    {:noreply, assign(socket, channels: channels, selected_category: nil)}
  end

  @impl true
  def handle_event("filter_category", %{"category_id" => id}, socket) do
    category_id = String.to_integer(id)
    channels = Streaming.list_live_channels_by_category(category_id)
    {:noreply, assign(socket, channels: channels, selected_category: category_id)}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    channels = Streaming.search_live_channels(query)
    {:noreply, assign(socket, channels: channels, search_query: query)}
  end
end
```

**Step 2: Create template**

Create `lib/computer_vision_web/live/directory_live.html.heex`:

```heex
<div class="min-h-screen bg-gray-900 text-white">
  <header class="border-b border-gray-800 px-6 py-4">
    <div class="max-w-7xl mx-auto flex items-center justify-between">
      <h1 class="text-2xl font-bold">ComputerVision</h1>
      <form phx-change="search" class="flex-1 max-w-md mx-8">
        <input
          type="text"
          name="query"
          value={@search_query}
          placeholder="Search streams..."
          class="w-full bg-gray-800 border border-gray-700 rounded-lg px-4 py-2 text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-purple-500"
          phx-debounce="300"
        />
      </form>
      <nav class="flex gap-4">
        <%= if @current_user do %>
          <.link navigate={~p"/dashboard"} class="text-gray-300 hover:text-white">Dashboard</.link>
          <.link href={~p"/users/log_out"} method="delete" class="text-gray-300 hover:text-white">Log out</.link>
        <% else %>
          <.link navigate={~p"/users/log_in"} class="text-gray-300 hover:text-white">Log in</.link>
          <.link navigate={~p"/users/register"} class="bg-purple-600 hover:bg-purple-700 px-4 py-2 rounded-lg">Sign up</.link>
        <% end %>
      </nav>
    </div>
  </header>

  <div class="max-w-7xl mx-auto px-6 py-8">
    <div class="flex gap-8">
      <!-- Category sidebar -->
      <aside class="w-48 flex-shrink-0">
        <h2 class="text-sm font-semibold text-gray-400 uppercase mb-3">Categories</h2>
        <ul class="space-y-1">
          <li>
            <button
              phx-click="filter_category"
              phx-value-category_id=""
              class={"block w-full text-left px-3 py-2 rounded-lg text-sm #{if @selected_category == nil, do: "bg-purple-600 text-white", else: "text-gray-300 hover:bg-gray-800"}"}
            >
              All
            </button>
          </li>
          <%= for category <- @categories do %>
            <li>
              <button
                phx-click="filter_category"
                phx-value-category_id={category.id}
                class={"block w-full text-left px-3 py-2 rounded-lg text-sm #{if @selected_category == category.id, do: "bg-purple-600 text-white", else: "text-gray-300 hover:bg-gray-800"}"}
              >
                <%= category.name %>
              </button>
            </li>
          <% end %>
        </ul>
      </aside>

      <!-- Channel grid -->
      <main class="flex-1">
        <%= if @channels == [] do %>
          <div class="text-center py-20 text-gray-500">
            <p class="text-xl">No one is live right now</p>
            <p class="mt-2">Check back later or start your own stream!</p>
          </div>
        <% else %>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <%= for channel <- @channels do %>
              <.link navigate={~p"/c/#{channel.user.username}"} class="group">
                <div class="bg-gray-800 rounded-lg overflow-hidden hover:ring-2 hover:ring-purple-500 transition">
                  <div class="aspect-video bg-gray-700 relative">
                    <span class="absolute top-2 left-2 bg-red-600 text-white text-xs font-bold px-2 py-1 rounded">
                      LIVE
                    </span>
                    <span class="absolute bottom-2 left-2 bg-black/70 text-white text-xs px-2 py-1 rounded">
                      <%= channel.viewer_count %> viewers
                    </span>
                  </div>
                  <div class="p-3">
                    <p class="font-semibold truncate"><%= channel.title || "Untitled Stream" %></p>
                    <p class="text-sm text-gray-400"><%= channel.user.username %></p>
                  </div>
                </div>
              </.link>
            <% end %>
          </div>
        <% end %>
      </main>
    </div>
  </div>
</div>
```

**Step 3: Add search/filter functions to Streaming context**

Add to `lib/computer_vision/streaming.ex`:

```elixir
def list_live_channels_by_category(category_id) do
  from(c in Channel,
    where: c.is_live == true and c.category_id == ^category_id,
    order_by: [desc: c.viewer_count],
    preload: [:user, :category]
  )
  |> Repo.all()
end

def search_live_channels(query) do
  search = "%#{query}%"

  from(c in Channel,
    join: u in assoc(c, :user),
    where: c.is_live == true,
    where: ilike(u.username, ^search) or ilike(c.title, ^search),
    order_by: [desc: c.viewer_count],
    preload: [:user, :category]
  )
  |> Repo.all()
end
```

Also update `list_live_channels` to preload `:category`:

```elixir
def list_live_channels do
  from(c in Channel,
    where: c.is_live == true,
    order_by: [desc: c.viewer_count],
    preload: [:user, :category]
  )
  |> Repo.all()
end
```

**Step 4: Update router**

Replace the home route in `lib/computer_vision_web/router.ex`:

```elixir
scope "/", ComputerVisionWeb do
  pipe_through :browser

  live "/", DirectoryLive
  get "/video/:filename", HlsController, :index
  live "/c/:username", ChannelLive
  live "/dashboard", DashboardLive
  live "/following", FollowingLive
  live "/settings", SettingsLive
end
```

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: add homepage directory with live channel grid, search, and category filter"
```

---

### Task 13: Build channel viewer page with HLS player and chat

**Files:**
- Create: `lib/computer_vision_web/live/channel_live.ex`
- Create: `lib/computer_vision_web/live/channel_live.html.heex`

**Step 1: Create the LiveView**

Create `lib/computer_vision_web/live/channel_live.ex`:

```elixir
defmodule ComputerVisionWeb.ChannelLive do
  use ComputerVisionWeb, :live_view

  alias ComputerVision.{Streaming, Social, Chat}
  alias ComputerVisionWeb.Presence

  @impl true
  def mount(%{"username" => username}, _session, socket) do
    user = ComputerVision.Accounts.get_user_by_username(username)
    channel = user && Streaming.get_channel_by_user(user.id)

    if is_nil(user) do
      {:ok, push_navigate(socket, to: ~p"/")}
    else
      if connected?(socket) do
        Phoenix.PubSub.subscribe(ComputerVision.PubSub, "chat:#{channel && channel.id}")
        Phoenix.PubSub.subscribe(ComputerVision.PubSub, "channel:#{channel && channel.id}")

        if channel do
          Presence.track(self(), "presence:#{channel.id}", socket.id, %{
            joined_at: System.monotonic_time()
          })

          Phoenix.PubSub.subscribe(ComputerVision.PubSub, "presence:#{channel.id}")
        end
      end

      current_user = socket.assigns[:current_user]
      following = current_user && channel && Social.following?(current_user.id, user.id)
      follower_count = Social.follower_count(user.id)
      viewer_count = if channel, do: Presence.list("presence:#{channel.id}") |> map_size(), else: 0
      emotes = if channel, do: Chat.list_emotes(channel.id), else: []

      {:ok,
       assign(socket,
         streamer: user,
         channel: channel,
         is_live: channel && channel.is_live,
         following: following || false,
         follower_count: follower_count,
         viewer_count: viewer_count,
         chat_messages: [],
         chat_form: to_form(%{}, as: "chat"),
         emotes: emotes
       )}
    end
  end

  @impl true
  def handle_info({:chat_message, message}, socket) do
    messages = socket.assigns.chat_messages ++ [message]
    # Keep last 200 messages
    messages = Enum.take(messages, -200)
    {:noreply, assign(socket, chat_messages: messages)}
  end

  @impl true
  def handle_info(:stream_ended, socket) do
    {:noreply, assign(socket, is_live: false)}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    channel = socket.assigns.channel
    viewer_count = Presence.list("presence:#{channel.id}") |> map_size()
    {:noreply, assign(socket, viewer_count: viewer_count)}
  end

  @impl true
  def handle_event("send_message", %{"chat" => %{"message" => content}}, socket) do
    current_user = socket.assigns.current_user
    channel = socket.assigns.channel

    cond do
      is_nil(current_user) ->
        {:noreply, put_flash(socket, :error, "You must be logged in to chat")}

      Chat.banned?(channel.id, current_user.id) ->
        {:noreply, put_flash(socket, :error, "You are banned from this chat")}

      true ->
        message = %{
          sender: %{id: current_user.id, username: current_user.username},
          content: content,
          timestamp: DateTime.utc_now()
        }

        Phoenix.PubSub.broadcast(
          ComputerVision.PubSub,
          "chat:#{channel.id}",
          {:chat_message, message}
        )

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_follow", _, socket) do
    current_user = socket.assigns.current_user
    streamer = socket.assigns.streamer

    if socket.assigns.following do
      Social.unfollow_user(current_user.id, streamer.id)
      {:noreply, assign(socket, following: false, follower_count: socket.assigns.follower_count - 1)}
    else
      {:ok, _} = Social.follow_user(current_user.id, streamer.id)
      {:noreply, assign(socket, following: true, follower_count: socket.assigns.follower_count + 1)}
    end
  end
end
```

**Step 2: Create the template**

Create `lib/computer_vision_web/live/channel_live.html.heex`:

```heex
<div class="min-h-screen bg-gray-900 text-white flex flex-col">
  <!-- Top bar -->
  <header class="border-b border-gray-800 px-4 py-3">
    <div class="flex items-center justify-between">
      <.link navigate={~p"/"} class="text-xl font-bold hover:text-purple-400">ComputerVision</.link>
      <nav class="flex gap-4">
        <%= if @current_user do %>
          <.link navigate={~p"/dashboard"} class="text-gray-300 hover:text-white text-sm">Dashboard</.link>
        <% end %>
      </nav>
    </div>
  </header>

  <div class="flex flex-1 overflow-hidden">
    <!-- Video + Info -->
    <main class="flex-1 flex flex-col">
      <!-- Player -->
      <div class="aspect-video bg-black relative">
        <%= if @is_live do %>
          <video
            id="player"
            controls
            autoplay
            playsinline
            class="w-full h-full"
            phx-hook="HlsPlayer"
            data-stream-url={"/api/v1/stream/#{@streamer.id}/live.m3u8"}
          />
          <span class="absolute top-3 left-3 bg-red-600 text-white text-xs font-bold px-2 py-1 rounded">
            LIVE
          </span>
          <span class="absolute top-3 right-3 bg-black/70 text-white text-xs px-2 py-1 rounded">
            <%= @viewer_count %> watching
          </span>
        <% else %>
          <div class="w-full h-full flex items-center justify-center text-gray-500">
            <div class="text-center">
              <p class="text-4xl mb-2">Offline</p>
              <p><%= @streamer.username %> is not streaming right now</p>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Stream info -->
      <div class="p-4 border-b border-gray-800">
        <div class="flex items-start justify-between">
          <div>
            <h1 class="text-lg font-semibold"><%= @channel && @channel.title || "#{@streamer.username}'s channel" %></h1>
            <p class="text-gray-400"><%= @streamer.username %></p>
            <p class="text-sm text-gray-500 mt-1"><%= @follower_count %> followers</p>
          </div>
          <%= if @current_user && @current_user.id != @streamer.id do %>
            <button
              phx-click="toggle_follow"
              class={"px-4 py-2 rounded-lg font-semibold text-sm #{if @following, do: "bg-gray-700 hover:bg-gray-600 text-white", else: "bg-purple-600 hover:bg-purple-700 text-white"}"}
            >
              <%= if @following, do: "Following", else: "Follow" %>
            </button>
          <% end %>
        </div>
      </div>
    </main>

    <!-- Chat sidebar -->
    <aside class="w-80 border-l border-gray-800 flex flex-col">
      <div class="p-3 border-b border-gray-800">
        <h2 class="font-semibold text-sm">Stream Chat</h2>
      </div>

      <!-- Messages -->
      <div id="chat-messages" class="flex-1 overflow-y-auto p-3 space-y-1" phx-update="stream">
        <%= for message <- @chat_messages do %>
          <div class="text-sm">
            <span class="font-semibold text-purple-400"><%= message.sender.username %></span>
            <span class="text-gray-300"><%= render_emotes(message.content, @emotes) %></span>
          </div>
        <% end %>
      </div>

      <!-- Chat input -->
      <%= if @current_user do %>
        <.form for={@chat_form} phx-submit="send_message" class="p-3 border-t border-gray-800">
          <div class="flex gap-2">
            <input
              type="text"
              name="chat[message]"
              placeholder="Send a message"
              autocomplete="off"
              class="flex-1 bg-gray-800 border border-gray-700 rounded px-3 py-2 text-sm text-white placeholder-gray-500 focus:outline-none focus:ring-1 focus:ring-purple-500"
            />
            <button type="submit" class="bg-purple-600 hover:bg-purple-700 px-3 py-2 rounded text-sm font-semibold">
              Chat
            </button>
          </div>
        </.form>
      <% else %>
        <div class="p-3 border-t border-gray-800 text-center">
          <.link navigate={~p"/users/log_in"} class="text-purple-400 hover:text-purple-300 text-sm">
            Log in to chat
          </.link>
        </div>
      <% end %>
    </aside>
  </div>
</div>
```

**Step 3: Add emote rendering helper**

Add to `lib/computer_vision_web/live/channel_live.ex`:

```elixir
defp render_emotes(content, emotes) do
  Enum.reduce(emotes, content, fn emote, acc ->
    String.replace(acc, emote.code, ~s(<img src="#{emote.image_url}" class="inline h-6 w-6" alt="#{emote.name}" />))
  end)
  |> Phoenix.HTML.raw()
end
```

**Step 4: Add HLS.js hook**

Create JS hook in `assets/js/hooks/hls_player.js`:

```javascript
const HlsPlayer = {
  mounted() {
    const video = this.el;
    const src = video.dataset.streamUrl;

    if (Hls.isSupported()) {
      const hls = new Hls({
        enableWorker: true,
        maxBufferLength: 1,
        liveBackBufferLength: 0,
        liveSyncDuration: 1,
        liveMaxLatencyDuration: 5,
        liveDurationInfinity: true,
        highBufferWatchdogPeriod: 1,
      });
      hls.attachMedia(video);
      hls.on(Hls.Events.MEDIA_ATTACHED, () => {
        hls.loadSource(src);
      });
      this.hls = hls;
    } else if (video.canPlayType("application/vnd.apple.mpegurl")) {
      video.src = src;
    }
  },
  destroyed() {
    if (this.hls) {
      this.hls.destroy();
    }
  },
};

export default HlsPlayer;
```

Register in `assets/js/app.js`:

```javascript
import HlsPlayer from "./hooks/hls_player";

let liveSocket = new LiveSocket("/live", Socket, {
  hooks: { HlsPlayer },
  params: { _csrf_token: csrfToken },
});
```

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: add channel viewer page with HLS player, chat, follows, and presence"
```

---

### Task 14: Build streamer dashboard

**Files:**
- Create: `lib/computer_vision_web/live/dashboard_live.ex`
- Create: `lib/computer_vision_web/live/dashboard_live.html.heex`

**Step 1: Create the LiveView**

Create `lib/computer_vision_web/live/dashboard_live.ex`:

```elixir
defmodule ComputerVisionWeb.DashboardLive do
  use ComputerVisionWeb, :live_view

  alias ComputerVision.{Streaming, Social, Accounts}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    channel = Streaming.get_channel_by_user(user.id) || create_default_channel(user)
    categories = Streaming.list_categories()
    follower_count = Social.follower_count(user.id)

    {:ok,
     assign(socket,
       channel: channel,
       categories: categories,
       follower_count: follower_count,
       show_stream_key: false,
       channel_form: to_form(Streaming.Channel.changeset(channel, %{}), as: "channel")
     )}
  end

  @impl true
  def handle_event("toggle_stream_key", _, socket) do
    {:noreply, assign(socket, show_stream_key: !socket.assigns.show_stream_key)}
  end

  @impl true
  def handle_event("regenerate_stream_key", _, socket) do
    user = socket.assigns.current_user
    {:ok, updated_user} = Accounts.regenerate_stream_key(user)
    {:noreply, assign(socket, current_user: updated_user)}
  end

  @impl true
  def handle_event("update_channel", %{"channel" => params}, socket) do
    case Streaming.update_channel(socket.assigns.channel, params) do
      {:ok, channel} ->
        {:noreply,
         socket
         |> assign(channel: channel)
         |> put_flash(:info, "Channel updated")}

      {:error, changeset} ->
        {:noreply, assign(socket, channel_form: to_form(changeset, as: "channel"))}
    end
  end

  defp create_default_channel(user) do
    {:ok, channel} = Streaming.create_channel(%{user_id: user.id})
    channel
  end
end
```

**Step 2: Create template**

Create `lib/computer_vision_web/live/dashboard_live.html.heex`:

```heex
<div class="min-h-screen bg-gray-900 text-white">
  <header class="border-b border-gray-800 px-6 py-4">
    <div class="max-w-4xl mx-auto flex items-center justify-between">
      <.link navigate={~p"/"} class="text-xl font-bold hover:text-purple-400">ComputerVision</.link>
      <h2 class="text-lg">Dashboard</h2>
    </div>
  </header>

  <div class="max-w-4xl mx-auto px-6 py-8 space-y-8">
    <!-- Stream Status -->
    <section class="bg-gray-800 rounded-lg p-6">
      <h3 class="text-lg font-semibold mb-4">Stream Status</h3>
      <div class="flex items-center gap-3">
        <div class={"w-3 h-3 rounded-full #{if @channel.is_live, do: "bg-red-500 animate-pulse", else: "bg-gray-500"}"} />
        <span class="text-lg"><%= if @channel.is_live, do: "Live", else: "Offline" %></span>
      </div>
      <p class="text-sm text-gray-400 mt-2"><%= @follower_count %> followers</p>
    </section>

    <!-- Stream Key -->
    <section class="bg-gray-800 rounded-lg p-6">
      <h3 class="text-lg font-semibold mb-4">Stream Key</h3>
      <p class="text-sm text-gray-400 mb-3">Use this key in OBS or your streaming software.</p>
      <div class="flex items-center gap-3">
        <code class="bg-gray-900 px-4 py-2 rounded font-mono text-sm flex-1">
          <%= if @show_stream_key do %>
            <%= @current_user.username %>_<%= @current_user.stream_key %>
          <% else %>
            ••••••••••••••••••••••
          <% end %>
        </code>
        <button phx-click="toggle_stream_key" class="text-sm text-purple-400 hover:text-purple-300">
          <%= if @show_stream_key, do: "Hide", else: "Show" %>
        </button>
      </div>
      <button
        phx-click="regenerate_stream_key"
        data-confirm="This will invalidate your current stream key. Continue?"
        class="mt-3 text-sm text-red-400 hover:text-red-300"
      >
        Regenerate key
      </button>
    </section>

    <!-- Channel Settings -->
    <section class="bg-gray-800 rounded-lg p-6">
      <h3 class="text-lg font-semibold mb-4">Channel Settings</h3>
      <.form for={@channel_form} phx-submit="update_channel" class="space-y-4">
        <div>
          <label class="block text-sm font-medium text-gray-300 mb-1">Stream Title</label>
          <input
            type="text"
            name="channel[title]"
            value={@channel.title}
            placeholder="What are you streaming?"
            class="w-full bg-gray-900 border border-gray-700 rounded-lg px-4 py-2 text-white focus:ring-2 focus:ring-purple-500 focus:outline-none"
          />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-300 mb-1">Category</label>
          <select
            name="channel[category_id]"
            class="w-full bg-gray-900 border border-gray-700 rounded-lg px-4 py-2 text-white focus:ring-2 focus:ring-purple-500 focus:outline-none"
          >
            <option value="">No category</option>
            <%= for category <- @categories do %>
              <option value={category.id} selected={@channel.category_id == category.id}>
                <%= category.name %>
              </option>
            <% end %>
          </select>
        </div>
        <div class="flex items-center gap-3">
          <input
            type="checkbox"
            name="channel[transcoding_enabled]"
            value="true"
            checked={@channel.transcoding_enabled}
            class="rounded bg-gray-900 border-gray-700 text-purple-600 focus:ring-purple-500"
          />
          <label class="text-sm text-gray-300">Enable multi-quality transcoding (requires server resources)</label>
        </div>
        <button type="submit" class="bg-purple-600 hover:bg-purple-700 px-6 py-2 rounded-lg font-semibold">
          Save Changes
        </button>
      </.form>
    </section>
  </div>
</div>
```

**Step 3: Add missing context functions**

Add to `lib/computer_vision/streaming.ex`:

```elixir
def update_channel(%Channel{} = channel, attrs) do
  channel
  |> Channel.changeset(attrs)
  |> Repo.update()
end
```

Add to `lib/computer_vision/accounts.ex`:

```elixir
def regenerate_stream_key(user) do
  user
  |> User.stream_key_changeset()
  |> Repo.update()
end
```

**Step 4: Commit**

```bash
git add -A
git commit -m "feat: add streamer dashboard with stream key, channel settings, and status"
```

---

### Task 15: Build admin panel

**Files:**
- Create: `lib/computer_vision_web/live/admin/admin_live.ex`
- Create: `lib/computer_vision_web/live/admin/categories_live.ex`
- Create: `lib/computer_vision_web/live/admin/users_live.ex`
- Modify: `lib/computer_vision_web/router.ex`

This task creates the admin pages for instance settings, category management, and user management. Follow the same LiveView patterns as Tasks 12-14. Use a `:require_admin` plug in the router pipeline to gate access.

Add admin routes:

```elixir
scope "/admin", ComputerVisionWeb.Admin do
  pipe_through [:browser, :require_authenticated_user, :require_admin]

  live "/", AdminLive
  live "/categories", CategoriesLive
  live "/users", UsersLive
  live "/emotes", EmotesLive
end
```

Create the `:require_admin` plug:

```elixir
def require_admin(conn, _opts) do
  if conn.assigns[:current_user] && conn.assigns.current_user.role == "admin" do
    conn
  else
    conn
    |> put_flash(:error, "You must be an admin to access this page.")
    |> redirect(to: ~p"/")
    |> halt()
  end
end
```

**Commit:**

```bash
git add -A
git commit -m "feat: add admin panel with instance settings, categories, and user management"
```

---

## Phase 4: Docker Compose & Deployment

### Task 16: Create Dockerfile and docker-compose.yml

**Files:**
- Create: `Dockerfile`
- Create: `docker-compose.yml`
- Create: `.env.example`
- Create: `lib/computer_vision/release.ex`

**Step 1: Create Release module**

Create `lib/computer_vision/release.ex`:

```elixir
defmodule ComputerVision.Release do
  @app :computer_vision

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
```

**Step 2: Create Dockerfile**

Create `Dockerfile`:

```dockerfile
# Build stage
FROM hexpm/elixir:1.16.1-erlang-26.2.2-debian-bookworm-20240130 AS build

RUN apt-get update -y && apt-get install -y build-essential git npm \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV=prod

COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
RUN mix deps.compile

COPY assets assets
COPY config config
COPY lib lib
COPY priv priv

RUN mix assets.deploy
RUN mix compile
RUN mix release

# Runtime stage
FROM debian:bookworm-slim

RUN apt-get update -y && apt-get install -y libstdc++6 openssl libncurses5 locales ffmpeg \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR /app
RUN chown nobody /app

COPY --from=build --chown=nobody:root /app/_build/prod/rel/computer_vision ./

USER nobody

EXPOSE 4000 1935

CMD ["bin/computer_vision", "start"]
```

**Step 3: Create docker-compose.yml**

```yaml
version: "3.8"

services:
  app:
    build: .
    ports:
      - "4000:4000"
      - "1935:1935"
    environment:
      - DATABASE_URL=ecto://postgres:postgres@db/computer_vision
      - SECRET_KEY_BASE=${SECRET_KEY_BASE}
      - PHX_HOST=${PHX_HOST:-localhost}
      - RTMP_PORT=1935
      - SMTP_HOST=${SMTP_HOST}
      - SMTP_PORT=${SMTP_PORT:-587}
      - SMTP_USER=${SMTP_USER}
      - SMTP_PASS=${SMTP_PASS}
      - STORAGE_TYPE=${STORAGE_TYPE:-local}
      - TRANSCODING_ENABLED=${TRANSCODING_ENABLED:-false}
      - REGISTRATION_OPEN=${REGISTRATION_OPEN:-true}
    volumes:
      - stream_data:/app/output
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped

  db:
    image: postgres:16-alpine
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres
      - POSTGRES_DB=computer_vision
    volumes:
      - pg_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data
    restart: unless-stopped

volumes:
  pg_data:
  redis_data:
  stream_data:
```

**Step 4: Create .env.example**

```bash
# Required
SECRET_KEY_BASE=generate-with-mix-phx-gen-secret
PHX_HOST=localhost

# SMTP (for magic link emails)
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USER=your-email@example.com
SMTP_PASS=your-password

# Optional
STORAGE_TYPE=local
TRANSCODING_ENABLED=false
REGISTRATION_OPEN=true
```

**Step 5: Commit**

```bash
git add Dockerfile docker-compose.yml .env.example lib/computer_vision/release.ex
git commit -m "feat: add Dockerfile, docker-compose.yml, and release module for self-hosting"
```

---

### Task 17: Update runtime.exs for Docker environment

**Files:**
- Modify: `config/runtime.exs`

Update `config/runtime.exs` to read all configuration from environment variables:

```elixir
import Config

if System.get_env("PHX_SERVER") do
  config :computer_vision, ComputerVisionWeb.Endpoint, server: true
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise "DATABASE_URL not set"

  config :computer_vision, ComputerVision.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE", "10"))

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise "SECRET_KEY_BASE not set"

  host = System.get_env("PHX_HOST", "localhost")
  port = String.to_integer(System.get_env("PORT", "4000"))

  config :computer_vision, ComputerVisionWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [ip: {0, 0, 0, 0}, port: port],
    secret_key_base: secret_key_base

  config :computer_vision,
    rtmp_port: String.to_integer(System.get_env("RTMP_PORT", "1935")),
    rtmp_host: {0, 0, 0, 0},
    storage_backend:
      case System.get_env("STORAGE_TYPE", "local") do
        "s3" -> ComputerVision.Storage.S3
        _ -> ComputerVision.Storage.Local
      end,
    storage_dir: System.get_env("STORAGE_DIR", "output"),
    transcoding_enabled: System.get_env("TRANSCODING_ENABLED", "false") == "true",
    max_concurrent_transcodes:
      String.to_integer(System.get_env("MAX_CONCURRENT_TRANSCODES", "2")),
    registration_open: System.get_env("REGISTRATION_OPEN", "true") == "true"

  # S3 config (if applicable)
  if System.get_env("STORAGE_TYPE") == "s3" do
    config :computer_vision,
      s3_bucket: System.get_env("S3_BUCKET")

    config :ex_aws,
      access_key_id: System.get_env("S3_ACCESS_KEY"),
      secret_access_key: System.get_env("S3_SECRET_KEY"),
      region: System.get_env("S3_REGION", "us-east-1")

    if endpoint = System.get_env("S3_ENDPOINT") do
      config :ex_aws, :s3,
        scheme: "https://",
        host: endpoint
    end
  end

  # SMTP config
  if smtp_host = System.get_env("SMTP_HOST") do
    config :computer_vision, ComputerVision.Mailer,
      adapter: Swoosh.Adapters.SMTP,
      relay: smtp_host,
      port: String.to_integer(System.get_env("SMTP_PORT", "587")),
      username: System.get_env("SMTP_USER"),
      password: System.get_env("SMTP_PASS"),
      tls: :always
  end
end
```

**Commit:**

```bash
git add config/runtime.exs
git commit -m "feat: configure runtime.exs for Docker environment variables"
```

---

### Task 18: Add first-user-is-admin logic

**Files:**
- Modify: `lib/computer_vision/accounts.ex`

Add logic so the first registered user automatically becomes admin:

```elixir
def register_user(attrs) do
  role = if user_count() == 0, do: "admin", else: "streamer"

  %User{}
  |> User.registration_changeset(Map.put(attrs, :role, role))
  |> Repo.insert()
end

defp user_count do
  Repo.aggregate(User, :count)
end
```

**Test:**

```elixir
test "first user becomes admin" do
  {:ok, user} = Accounts.register_user(%{email: "first@test.com", username: "first", password: "password123456"})
  assert user.role == "admin"
end

test "subsequent users are streamers" do
  {:ok, _} = Accounts.register_user(%{email: "first@test.com", username: "first", password: "password123456"})
  {:ok, user} = Accounts.register_user(%{email: "second@test.com", username: "second", password: "password123456"})
  assert user.role == "streamer"
end
```

**Commit:**

```bash
git add -A
git commit -m "feat: first registered user automatically becomes admin"
```

---

## Phase 5: Notification System

### Task 19: Add notification worker GenServer

**Files:**
- Create: `lib/computer_vision/notification_worker.ex`
- Modify: `lib/computer_vision/application.ex`

**Step 1: Create NotificationWorker**

```elixir
defmodule ComputerVision.NotificationWorker do
  use GenServer

  alias ComputerVision.Social

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Phoenix.PubSub.subscribe(ComputerVision.PubSub, "streams")
    {:ok, %{}}
  end

  @impl true
  def handle_info({:streamer_went_live, user, channel}, state) do
    follower_ids = Social.list_follower_ids(user.id)

    Enum.each(follower_ids, fn follower_id ->
      Social.create_notification(%{
        user_id: follower_id,
        type: "streamer_went_live",
        payload: %{
          "username" => user.username,
          "channel_title" => channel.title,
          "channel_id" => channel.id
        }
      })

      Phoenix.PubSub.broadcast(
        ComputerVision.PubSub,
        "user:#{follower_id}",
        {:notification, :streamer_went_live, user}
      )
    end)

    {:noreply, state}
  end

  @impl true
  def handle_info(_, state), do: {:noreply, state}
end
```

**Step 2: Add to supervision tree**

Add `ComputerVision.NotificationWorker` to children in `application.ex`.

**Step 3: Commit**

```bash
git add -A
git commit -m "feat: add notification worker for streamer-went-live broadcasts"
```

---

### Task 20: Update root layout with dark theme and notification badge

**Files:**
- Modify: `lib/computer_vision_web/components/layouts/root.html.heex`
- Modify: `lib/computer_vision_web/components/layouts/app.html.heex`

Update the root layout to use a dark theme base and include HLS.js:

```heex
<!DOCTYPE html>
<html lang="en" class="dark">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="csrf-token" content={get_csrf_token()} />
    <.live_title suffix=" · ComputerVision">
      <%= assigns[:page_title] || "ComputerVision" %>
    </.live_title>
    <link phx-track-static rel="stylesheet" href={~p"/assets/app.css"} />
    <script src="https://cdn.jsdelivr.net/npm/hls.js@latest"></script>
    <script defer phx-track-static type="text/javascript" src={~p"/assets/app.js"}></script>
  </head>
  <body class="bg-gray-900 text-white">
    <%= @inner_content %>
  </body>
</html>
```

**Commit:**

```bash
git add -A
git commit -m "feat: update root layout with dark theme and HLS.js"
```

---

## Summary

**Total tasks: 20**

**Phase 1 (Foundation):** Tasks 1-7 — Dependencies, auth, schemas, migrations
**Phase 2 (Streaming):** Tasks 8-10 — Supervision tree, storage, RTMP validation
**Phase 3 (UI):** Tasks 11-15 — Presence, directory, channel, dashboard, admin
**Phase 4 (Deploy):** Tasks 16-18 — Docker, runtime config, first-user-admin
**Phase 5 (Polish):** Tasks 19-20 — Notifications, layout

Each task follows TDD: write failing test → implement → verify → commit.
