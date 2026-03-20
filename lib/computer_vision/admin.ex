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
        |> Repo.insert!()

      setting ->
        setting
        |> InstanceSetting.changeset(%{value: value})
        |> Repo.update!()
    end
  end
end
