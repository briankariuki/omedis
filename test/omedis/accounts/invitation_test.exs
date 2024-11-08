defmodule Omedis.Accounts.InvitationTest do
  use Omedis.DataCase, async: true

  import Omedis.Fixtures

  alias Omedis.Accounts.Invitation
  alias Omedis.Accounts.InvitationGroup

  setup do
    {:ok, owner} = create_user()
    {:ok, organisation} = create_organisation(%{owner_id: owner.id})
    {:ok, group} = create_group(%{organisation_id: organisation.id})

    {:ok, authorized_user} = create_user()
    create_group_membership(%{user_id: authorized_user.id, group_id: group.id})

    create_access_right(%{
      resource_name: "Invitation",
      create: true,
      organisation_id: organisation.id,
      group_id: group.id
    })

    create_access_right(%{
      group_id: group.id,
      read: true,
      resource_name: "Organisation",
      organisation_id: organisation.id,
      write: true
    })

    create_access_right(%{
      group_id: group.id,
      read: true,
      resource_name: "Group",
      organisation_id: organisation.id,
      write: true
    })

    {:ok, unauthorized_user} = create_user()
    {:ok, group_2} = create_group()
    create_group_membership(%{user_id: unauthorized_user.id, group_id: group_2.id})

    %{
      authorized_user: authorized_user,
      group: group,
      owner: owner,
      tenant: organisation,
      unauthorized_user: unauthorized_user
    }
  end

  describe "create/1" do
    test "organisation owner can create invitation", %{
      group: group,
      owner: owner,
      tenant: organisation
    } do
      attrs = %{
        email: "test@example.com",
        language: "en",
        creator_id: owner.id,
        organisation_id: organisation.id,
        groups: [group.id]
      }

      assert {:ok, invitation} = Invitation.create(attrs, actor: owner, tenant: organisation)
      assert invitation.email == "test@example.com"
      assert invitation.language == "en"
      assert invitation.creator_id == owner.id
      assert invitation.organisation_id == organisation.id

      invitation_groups = Ash.read!(InvitationGroup, authorize?: false)
      group_ids = Enum.map(invitation_groups, & &1.group_id)
      assert group.id in group_ids
    end

    test "authorized user can create invitation", %{
      tenant: organisation,
      group: group,
      authorized_user: user
    } do
      attrs = %{
        email: "test@example.com",
        language: "en",
        creator_id: user.id,
        organisation_id: organisation.id,
        groups: [group.id]
      }

      assert {:ok, invitation} = Invitation.create(attrs, actor: user, tenant: organisation)
      assert invitation.email == "test@example.com"

      invitation_groups = Ash.read!(InvitationGroup, authorize?: false)
      group_ids = Enum.map(invitation_groups, & &1.group_id)
      assert group.id in group_ids
    end

    test "unauthorized user cannot create invitation", %{
      tenant: organisation,
      group: group,
      unauthorized_user: user
    } do
      attrs = %{
        email: "test@example.com",
        language: "en",
        creator_id: user.id,
        organisation_id: organisation.id,
        groups: [group.id]
      }

      assert {:error, %Ash.Error.Forbidden{}} =
               Invitation.create(attrs, actor: user, tenant: organisation)
    end

    test "validates required attributes", %{tenant: organisation, owner: owner, group: group} do
      attrs = %{
        language: "en",
        creator_id: owner.id,
        organisation_id: organisation.id,
        groups: [group.id]
      }

      assert {:error, %Ash.Error.Invalid{}} =
               Invitation.create(attrs, actor: owner, tenant: organisation)
    end
  end
end
