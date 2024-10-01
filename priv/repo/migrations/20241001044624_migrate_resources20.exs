defmodule Omedis.Repo.Migrations.MigrateResources20 do
  @moduledoc """
  Updates resources based on their most recent snapshots.

  This file was autogenerated with `mix ash_postgres.generate_migrations`
  """

  use Ecto.Migration

  def up do
    create unique_index(:groups, [:slug], name: "groups_unique_slug_index")
  end

  def down do
    drop_if_exists unique_index(:groups, [:slug], name: "groups_unique_slug_index")
  end
end