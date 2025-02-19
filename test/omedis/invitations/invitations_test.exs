defmodule Omedis.InvitationsTest do
  use Omedis.DataCase, async: true

  import Omedis.Fixtures
  import Omedis.TestUtils

  alias Omedis.Invitations
  alias Omedis.Invitations.Invitation.Workers.InvitationEmailWorker
  alias Omedis.Invitations.Invitation.Workers.InvitationExpirationWorker
  alias Omedis.Invitations.InvitationGroup

  @params %{email: "test@example.com", language: "en"}

  setup do
    {:ok, owner} = create_user()
    organisation = fetch_users_organisation(owner.id)
    {:ok, authorized_user} = create_user()
    {:ok, group} = create_group(organisation)

    {:ok, _} =
      create_group_membership(organisation, %{group_id: group.id, user_id: authorized_user.id})

    {:ok, _} =
      create_access_right(organisation, %{
        group_id: group.id,
        read: true,
        resource_name: "Group"
      })

    {:ok, invitation_access_right} =
      create_access_right(organisation, %{
        resource_name: "Invitation",
        group_id: group.id,
        read: true,
        create: true,
        destroy: true,
        update: true
      })

    {:ok, _} =
      create_access_right(organisation, %{
        group_id: group.id,
        read: true,
        resource_name: "Organisation"
      })

    {:ok, unauthorized_user} = create_user()
    {:ok, group_2} = create_group(organisation)

    {:ok, _} =
      create_group_membership(organisation, %{user_id: unauthorized_user.id, group_id: group_2.id})

    %{
      access_right: invitation_access_right,
      authorized_user: authorized_user,
      owner: owner,
      organisation: organisation,
      group: group,
      unauthorized_user: unauthorized_user
    }
  end

  describe "create_invitation/1" do
    test "organisation owner can create invitation and queue a job to send an invitation email",
         %{
           group: group,
           owner: owner,
           organisation: organisation
         } do
      attrs = %{
        email: "test@example.com",
        language: "en",
        creator_id: owner.id,
        groups: [group.id]
      }

      assert {:ok, invitation} =
               Invitations.create_invitation(attrs, actor: owner, tenant: organisation)

      assert_enqueued(
        worker: InvitationEmailWorker,
        args: %{
          actor_id: owner.id,
          id: invitation.id
        },
        queue: :invitation
      )

      assert invitation.email == Ash.CiString.new("test@example.com")
      assert invitation.language == "en"
      assert invitation.creator_id == owner.id
      assert invitation.organisation_id == organisation.id

      invitation_groups = Ash.read!(InvitationGroup, authorize?: false, tenant: organisation)
      group_ids = Enum.map(invitation_groups, & &1.group_id)
      assert group.id in group_ids
    end

    test "authorized user can create invitation and queue a job to send an invitation email", %{
      organisation: organisation,
      group: group,
      authorized_user: user
    } do
      attrs = %{
        email: "test@example.com",
        language: "en",
        creator_id: user.id,
        groups: [group.id]
      }

      assert {:ok, invitation} =
               Invitations.create_invitation(attrs, actor: user, tenant: organisation)

      assert_enqueued(
        worker: InvitationEmailWorker,
        args: %{actor_id: user.id, id: invitation.id},
        queue: :invitation
      )

      assert invitation.email == Ash.CiString.new("test@example.com")

      invitation_groups = Ash.read!(InvitationGroup, authorize?: false, tenant: organisation)
      group_ids = Enum.map(invitation_groups, & &1.group_id)
      assert group.id in group_ids
    end

    test "unauthorized user cannot create invitation and cannot queue a job to send an invitation email",
         %{
           organisation: organisation,
           group: group,
           unauthorized_user: user
         } do
      attrs = %{
        email: "test@example.com",
        language: "en",
        creator_id: user.id,
        groups: [group.id]
      }

      assert {:error, %Ash.Error.Forbidden{}} =
               Invitations.create_invitation(attrs, actor: user, tenant: organisation)

      refute_enqueued(worker: InvitationEmailWorker)
    end

    test "can create invitation for same email if there is an expired invitation",
         %{
           group: group,
           organisation: organisation,
           owner: owner
         } do
      {:ok, _} =
        create_invitation(organisation, %{
          email: "test@example.com",
          creator_id: owner.id,
          status: :expired
        })

      attrs = %{
        email: "test@example.com",
        language: "en",
        creator_id: owner.id,
        groups: [group.id]
      }

      assert {:ok, invitation} =
               Invitations.create_invitation(attrs, actor: owner, tenant: organisation)

      assert invitation.email == Ash.CiString.new("test@example.com")
    end

    test "schedules invitation expiration to run at the time specified in the expires_at attribute",
         %{
           organisation: organisation,
           owner: owner
         } do
      attrs =
        Invitations.Invitation
        |> attrs_for(organisation)
        |> Map.put(:creator_id, owner.id)

      assert {:ok, invitation} =
               Invitations.create_invitation(attrs, actor: owner, tenant: organisation)

      assert_enqueued(
        worker: InvitationExpirationWorker,
        args: %{"invitation_id" => invitation.id},
        scheduled_at: invitation.expires_at
      )
    end

    test "does not create invitation if expiration time is in the past",
         %{
           organisation: organisation,
           owner: owner
         } do
      attrs =
        Invitations.Invitation
        |> attrs_for(organisation)
        |> Map.put(:creator_id, owner.id)
        |> Map.put(:expires_at, DateTime.add(DateTime.utc_now(), -1, :second))

      assert {:error, %Ash.Error.Invalid{errors: errors}} =
               Invitations.create_invitation(attrs, actor: owner, tenant: organisation)

      assert [
               _,
               %Ash.Error.Changes.InvalidChanges{
                 message: "expiration time must be in the future"
               }
             ] =
               errors

      refute_enqueued(worker: InvitationExpirationWorker)
    end

    test "deletes existing pending invitation and creates a new one",
         %{
           group: group,
           organisation: organisation,
           owner: owner
         } do
      one_second_ago = DateTime.add(DateTime.utc_now(), -1, :second)

      {:ok, existing_invitation} =
        create_invitation(
          organisation,
          %{
            email: "test@example.com",
            creator_id: owner.id
          },
          context: %{created_at: one_second_ago}
        )

      attrs = %{
        email: "test@example.com",
        language: "en",
        creator_id: owner.id,
        groups: [group.id]
      }

      assert {:ok, new_invitation} =
               Invitations.create_invitation(attrs, actor: owner, tenant: organisation)

      assert new_invitation.email == Ash.CiString.new("test@example.com")

      assert {:error, %Ash.Error.Query.NotFound{}} =
               Invitations.get_invitation_by_id(existing_invitation.id)
    end

    test "validates required attributes", %{
      organisation: organisation,
      owner: owner,
      group: group
    } do
      attrs = %{
        language: "en",
        creator_id: owner.id,
        groups: [group.id]
      }

      assert {:error, %Ash.Error.Invalid{}} =
               Invitations.create_invitation(attrs, actor: owner, tenant: organisation)

      refute_enqueued(worker: InvitationExpirationWorker)
    end
  end

  describe "accept_invitation/2" do
    test "updates invitation status to accepted", %{
      organisation: organisation,
      owner: owner
    } do
      {:ok, invitation} = create_invitation(organisation)

      assert {:ok, updated_invitation} =
               Invitations.accept_invitation(invitation, actor: owner, tenant: organisation)

      assert updated_invitation.status == :accepted
    end
  end

  describe "mark_invitation_as_expireds/2" do
    test "updates invitation status to expired", %{
      organisation: organisation,
      owner: owner
    } do
      {:ok, invitation} = create_invitation(organisation)

      assert {:ok, updated_invitation} =
               Invitations.mark_invitation_as_expired(invitation,
                 actor: owner,
                 tenant: organisation
               )

      assert updated_invitation.status == :expired
    end
  end

  describe "get_invitation_by_id/1" do
    test "returns invitation if it has not expired", %{organisation: organisation} do
      {:ok, invitation} = create_invitation(organisation)

      assert {:ok, _invitation} = Invitations.get_invitation_by_id(invitation.id)
    end

    test "returns an error if invitation has expired", %{
      organisation: organisation,
      owner: owner
    } do
      {:ok, invitation} =
        create_invitation(organisation, %{
          creator_id: owner.id,
          status: :expired
        })

      assert {:error, %Ash.Error.Query.NotFound{}} =
               Invitations.get_invitation_by_id(invitation.id)
    end

    test "returns an error if invitation does not exist" do
      assert {:error, %Ash.Error.Query.NotFound{}} =
               Invitations.get_invitation_by_id(Ecto.UUID.generate())
    end
  end

  describe "delete_invitation/2" do
    setup %{organisation: organisation} do
      {:ok, invitation} = create_invitation(organisation)

      %{invitation: invitation}
    end

    test "organisation owner can destroy an invitation", %{
      organisation: organisation,
      invitation: invitation,
      owner: organisation_owner
    } do
      assert :ok =
               Invitations.delete_invitation(invitation,
                 actor: organisation_owner,
                 tenant: organisation
               )
    end

    test "authorized user can destroy an invitation", %{
      authorized_user: authorized_user,
      invitation: invitation,
      organisation: organisation
    } do
      assert :ok =
               Invitations.delete_invitation(invitation,
                 actor: authorized_user,
                 tenant: organisation
               )
    end

    test "unauthorized user cannot destroy an invitation", %{
      access_right: access_right,
      authorized_user: authorized_user,
      invitation: invitation,
      organisation: organisation
    } do
      # Remove access rights for the user
      Ash.destroy!(access_right)

      assert {:error, %Ash.Error.Forbidden{}} =
               Invitations.delete_invitation(invitation,
                 actor: authorized_user,
                 tenant: organisation
               )
    end
  end

  describe "list_paginated_invitations/1" do
    test "returns invitations for the organisation owner", %{
      organisation: organisation,
      owner: organisation_owner
    } do
      {:ok, invitation} = create_invitation(organisation)

      assert {:ok, %{results: results, count: 1}} =
               Invitations.list_paginated_invitations(
                 actor: organisation_owner,
                 page: [limit: 10, offset: 0],
                 tenant: organisation
               )

      assert hd(results).id == invitation.id
    end

    test "returns invitations for the authorized user", %{
      authorized_user: authorized_user,
      organisation: organisation
    } do
      creator_id = authorized_user.id

      for i <- 1..15 do
        params =
          Map.merge(@params, %{
            creator_id: creator_id,
            email: "test#{i}@example.com"
          })

        {:ok, _} = create_invitation(organisation, params)
      end

      assert {:ok, %{results: results, count: 15}} =
               Invitations.list_paginated_invitations(
                 actor: authorized_user,
                 page: [limit: 10, offset: 0],
                 tenant: organisation
               )

      assert length(results) == 10

      # Second page
      assert {:ok, %{results: more_results}} =
               Invitations.list_paginated_invitations(
                 actor: authorized_user,
                 page: [limit: 10, offset: 10],
                 tenant: organisation
               )

      assert length(more_results) == 5
    end

    test "sorts invitations by inserted_at", %{
      organisation: organisation,
      owner: organisation_owner
    } do
      invitations =
        for i <- 1..3 do
          {:ok, invitation} =
            create_invitation(organisation, %{
              creator_id: organisation_owner.id
            })

          invitation
          |> Ash.Changeset.for_update(
            :update,
            %{inserted_at: Omedis.TestUtils.time_after(-i * 12_000)},
            authorize?: false
          )
          |> Ash.update!()
        end

      assert {:ok, %{results: results}} =
               Invitations.list_paginated_invitations(%{sort_order: :asc},
                 actor: organisation_owner,
                 tenant: organisation
               )

      assert Enum.map(results, & &1.inserted_at) ==
               invitations |> Enum.map(& &1.inserted_at) |> Enum.reverse()
    end

    test "does not return invitations if user is unauthorized", %{
      access_right: access_right,
      authorized_user: authorized_user,
      organisation: organisation
    } do
      creator_id = authorized_user.id

      for i <- 1..15 do
        params =
          Map.merge(@params, %{
            creator_id: creator_id,
            email: "test#{i}@example.com"
          })

        {:ok, _} = create_invitation(organisation, params)
      end

      # Remove access rights for the user
      Ash.destroy!(access_right, tenant: organisation)

      assert {:ok, %{results: [], count: 0}} =
               Invitations.list_paginated_invitations(
                 actor: authorized_user,
                 page: [limit: 20, offset: 0],
                 tenant: organisation
               )
    end
  end
end
