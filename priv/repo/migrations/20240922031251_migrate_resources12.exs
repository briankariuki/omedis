defmodule Omedis.Repo.Migrations.MigrateResources12 do
  @moduledoc """
  Updates resources based on their most recent snapshots.

  This file was autogenerated with `mix ash_postgres.generate_migrations`
  """

  use Ecto.Migration

  def up do
    alter table(:tenants) do
      modify :daily_end_at, :time, default: fragment("'18:00:00'")
    end
  end

  def down do
    alter table(:tenants) do
      modify :daily_end_at, :time, default: fragment("'17:00:00'")
    end
  end
end
