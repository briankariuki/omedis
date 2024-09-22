defmodule Omedis.TenantTest do
  use Omedis.DataCase

  alias Omedis.Accounts.Tenant
  alias Omedis.Accounts.User
  alias Omedis.Factory

  describe "Tenant Resource Unit Tests" do
    test "read/0  returns all tenants" do
      Factory.insert_tenant(%{slug: "tenant-one"})

      {:ok, tenants} = Tenant.read()

      assert Enum.empty?(tenants) == false
    end

    test "create/1 creates a tenant given valid attributes" do
      # a tenant is created with the valid attributes
      assert {:ok, _tenant} =
               Tenant.create(%{
                 name: "Test",
                 street: "Wall Street",
                 zip_code: "12345",
                 city: "New York",
                 country: "USA",
                 slug: "tenant-one"
               })

      #  an error is returned when the attributes are invalid

      assert {:error, _} =
               User.create(%{
                 name: "Test"
               })
    end

    test "update/2 updates a tenant given valid attributes" do
      {:ok, tenant} =
        Factory.insert_tenant(%{slug: "tenant-one"})

      assert {:ok, tenant} =
               Tenant.update(tenant, %{
                 name: "Test Changed"
               })

      assert tenant.name == "Test Changed"
    end

    test "destroy/1 deletes a tenant" do
      {:ok, tenant} =
        Factory.insert_tenant(%{slug: "tenant-one"})

      {:ok, tenants} = Tenant.read()
      assert Enum.empty?(tenants) == false

      assert :ok = Tenant.destroy(tenant)

      {:ok, tenants} = Tenant.read()
      assert Enum.empty?(tenants) == true
    end

    test "by_id/1 returns a tenant given a valid id" do
      {:ok, tenant} =
        Factory.insert_tenant(%{slug: "tenant-one"})

      {:ok, fetched_tenant} = Tenant.by_id(tenant.id)

      assert tenant.id == fetched_tenant.id
    end

    test "by_slug/1 returns a tenant given a slug" do
      {:ok, tenant} =
        Factory.insert_tenant(%{slug: "tenant-one"})

      {:ok, fetched_tenant} = Tenant.by_slug(tenant.slug)

      assert tenant.slug == fetched_tenant.slug
    end

    test "by_owner_id/1 returns a tenant for a specific user" do
      {:ok, user} =
        Factory.insert_user(%{email: "test@gmail.com"})

      {:ok, tenant} =
        Factory.insert_tenant(%{slug: "tenant-one", owner_id: user.id})

      {:ok, fetched_tenant} = Tenant.by_owner_id(user.id)

      assert tenant.owner_id == fetched_tenant.owner_id
    end
  end
end