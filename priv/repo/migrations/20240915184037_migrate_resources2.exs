defmodule Omedis.Repo.Migrations.MigrateResources2 do
  @moduledoc """
  Updates resources based on their most recent snapshots.

  This file was autogenerated with `mix ash_postgres.generate_migrations`
  """

  use Ecto.Migration

  def up do
    create table(:tenants, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :name, :text, null: false
      add :additional_info, :text
      add :street, :text, null: false
      add :street2, :text
      add :po_box, :text
      add :zip_code, :text, null: false
      add :city, :text, null: false
      add :canton, :text
      add :country, :text, null: false
      add :description, :text

      add :owner_id,
          references(:users,
            column: :id,
            name: "tenants_owner_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          ),
          null: false

      add :phone, :text
      add :fax, :text
      add :email, :text
      add :website, :text
      add :zsr_number, :text
      add :ean_gln, :text
      add :uid_bfs_number, :text
      add :trade_register_no, :text
      add :bur_number, :text
      add :account_number, :text
      add :iban, :text
      add :bic, :text
      add :bank, :text
      add :account_holder, :text

      add :created_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end
  end

  def down do
    drop constraint(:tenants, "tenants_owner_id_fkey")

    drop table(:tenants)
  end
end