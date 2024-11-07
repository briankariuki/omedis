defmodule Omedis.Accounts.ActivityTest do
  use Omedis.DataCase, async: true

  import Omedis.Fixtures

  alias Omedis.Accounts.Activity

  setup do
    {:ok, owner} = create_user()
    {:ok, organisation} = create_organisation(%{owner_id: owner.id})
    {:ok, group} = create_group(%{organisation_id: organisation.id})
    {:ok, project} = create_project(%{organisation_id: organisation.id})
    {:ok, authorized_user} = create_user()

    {:ok, _} = create_group_membership(%{group_id: group.id, user_id: authorized_user.id})

    {:ok, _} =
      create_access_right(%{
        group_id: group.id,
        read: true,
        resource_name: "Activity",
        organisation_id: organisation.id,
        write: true
      })

    {:ok, _} =
      create_access_right(%{
        group_id: group.id,
        read: true,
        resource_name: "Organisation",
        organisation_id: organisation.id,
        write: true
      })

    {:ok, user} = create_user()
    {:ok, group_2} = create_group()
    {:ok, _} = create_group_membership(%{group_id: group_2.id, user_id: user.id})

    {:ok, _} =
      create_access_right(%{
        group_id: group_2.id,
        read: true,
        resource_name: "Organisation",
        organisation_id: organisation.id,
        write: true
      })

    %{
      owner: owner,
      organisation: organisation,
      group: group,
      project: project,
      authorized_user: authorized_user,
      user: user
    }
  end

  describe "create/2" do
    test "organisation owner can create an activity", %{
      owner: owner,
      organisation: organisation,
      group: group,
      project: project
    } do
      attrs = %{
        name: "Test Activity",
        group_id: group.id,
        project_id: project.id,
        color_code: "#FF0000",
        slug: "test-activity"
      }

      assert {:ok, activity} = Activity.create(attrs, actor: owner, tenant: organisation)
      assert activity.name == "Test Activity"
      assert activity.color_code == "#FF0000"
      assert activity.position == 1
    end

    test "authorized user can create an activity", %{
      authorized_user: authorized_user,
      organisation: organisation,
      group: group,
      project: project
    } do
      attrs = %{
        name: "Test Activity",
        group_id: group.id,
        project_id: project.id,
        color_code: "#FF0000",
        slug: "test-activity"
      }

      assert {:ok, activity} =
               Activity.create(attrs, actor: authorized_user, tenant: organisation)

      assert activity.name == "Test Activity"
    end

    test "unauthorized user cannot create an activity", %{
      user: user,
      organisation: organisation,
      group: group,
      project: project
    } do
      attrs = %{
        name: "Test Activity",
        group_id: group.id,
        project_id: project.id,
        color_code: "#FF0000",
        slug: "test-activity"
      }

      assert {:error, %Ash.Error.Forbidden{}} =
               Activity.create(attrs, actor: user, tenant: organisation)
    end

    test "returns error with invalid attributes", %{
      owner: owner,
      organisation: organisation,
      group: group,
      project: project
    } do
      attrs = %{
        group_id: group.id,
        project_id: project.id
      }

      assert {:error, %Ash.Error.Invalid{}} =
               Activity.create(attrs, actor: owner, tenant: organisation)
    end
  end

  describe "update/2" do
    test "organisation owner can update an activity", %{
      owner: owner,
      organisation: organisation,
      group: group,
      project: project
    } do
      {:ok, activity} =
        create_activity(%{
          name: "Test Activity",
          group_id: group.id,
          project_id: project.id,
          color_code: "#FF0000",
          slug: "test-activity"
        })

      assert {:ok, updated_activity} =
               Activity.update(activity, %{name: "Updated Activity"},
                 actor: owner,
                 tenant: organisation
               )

      assert updated_activity.name == "Updated Activity"
    end

    test "authorized user can update an activity", %{
      authorized_user: authorized_user,
      organisation: organisation,
      group: group,
      project: project
    } do
      {:ok, activity} =
        create_activity(%{
          name: "Test Activity",
          group_id: group.id,
          project_id: project.id,
          color_code: "#FF0000",
          slug: "test-activity"
        })

      assert {:ok, updated_activity} =
               Activity.update(activity, %{name: "Updated Activity"},
                 actor: authorized_user,
                 tenant: organisation
               )

      assert updated_activity.name == "Updated Activity"
    end

    test "unauthorized user cannot update an activity", %{
      user: user,
      organisation: organisation,
      group: group,
      project: project
    } do
      {:ok, activity} =
        create_activity(%{
          name: "Test Activity",
          group_id: group.id,
          project_id: project.id,
          color_code: "#FF0000",
          slug: "test-activity"
        })

      assert {:error, %Ash.Error.Forbidden{}} =
               Activity.update(activity, %{name: "Updated Activity"},
                 actor: user,
                 tenant: organisation
               )
    end

    test "returns error with invalid attributes", %{
      owner: owner,
      organisation: organisation,
      group: group,
      project: project
    } do
      {:ok, activity} =
        create_activity(%{
          name: "Test Activity",
          group_id: group.id,
          project_id: project.id,
          color_code: "#FF0000",
          slug: "test-activity"
        })

      invalid_attrs = %{
        name: "",
        color_code: "invalid-color"
      }

      assert {:error, %Ash.Error.Invalid{}} =
               Activity.update(activity, invalid_attrs, actor: owner, tenant: organisation)
    end
  end

  describe "by_id/2" do
    test "returns activity for organisation owner", %{
      owner: owner,
      organisation: organisation,
      group: group,
      project: project
    } do
      {:ok, activity} =
        create_activity(%{
          name: "Test Activity",
          group_id: group.id,
          project_id: project.id,
          color_code: "#FF0000",
          slug: "test-activity"
        })

      assert {:ok, found_activity} =
               Activity.by_id(activity.id, actor: owner, tenant: organisation)

      assert found_activity.id == activity.id
    end

    test "returns activity for authorized user", %{
      authorized_user: authorized_user,
      organisation: organisation,
      group: group,
      project: project
    } do
      {:ok, activity} =
        create_activity(%{
          name: "Test Activity",
          group_id: group.id,
          project_id: project.id,
          color_code: "#FF0000",
          slug: "test-activity"
        })

      assert {:ok, found_activity} =
               Activity.by_id(activity.id, actor: authorized_user, tenant: organisation)

      assert found_activity.id == activity.id
    end

    test "returns error for unauthorized user", %{
      user: user,
      organisation: organisation,
      group: group,
      project: project
    } do
      {:ok, activity} =
        create_activity(%{
          name: "Test Activity",
          group_id: group.id,
          project_id: project.id,
          color_code: "#FF0000",
          slug: "test-activity"
        })

      assert {:error, %Ash.Error.Query.NotFound{}} =
               Activity.by_id(activity.id, actor: user, tenant: organisation)
    end
  end

  describe "list_paginated/1" do
    setup %{group: group, project: project} do
      Enum.each(1..15, fn _ ->
        {:ok, _} =
          create_activity(%{
            group_id: group.id,
            project_id: project.id
          })
      end)

      :ok
    end

    test "returns paginated activities for organisation owner", %{
      group: group,
      owner: owner,
      organisation: organisation
    } do
      assert {:ok, paginated_result} =
               Activity.list_paginated(
                 %{group_id: group.id},
                 page: [offset: 0, limit: 10],
                 actor: owner,
                 tenant: organisation
               )

      assert length(paginated_result.results) == 10
    end

    test "returns paginated activities for authorized user", %{
      authorized_user: authorized_user,
      group: group,
      organisation: organisation
    } do
      assert {:ok, paginated_result} =
               Activity.list_paginated(
                 %{group_id: group.id},
                 page: [offset: 0, limit: 10],
                 actor: authorized_user,
                 tenant: organisation
               )

      assert length(paginated_result.results) == 10
    end

    test "does not return paginated activities for unauthorized user", %{
      group: group,
      organisation: organisation,
      user: user
    } do
      assert {:ok, paginated_result} =
               Activity.list_paginated(
                 %{group_id: group.id},
                 page: [offset: 0, limit: 10],
                 actor: user,
                 tenant: organisation
               )

      assert Enum.empty?(paginated_result.results)
    end
  end

  describe "by_group_id_and_project_id/2" do
    setup %{group: group, project: project} do
      {:ok, activity} =
        create_activity(%{
          name: "Test Activity",
          group_id: group.id,
          project_id: project.id
        })

      %{activity: activity}
    end

    test "returns activities for specific group and project for organisation owner", %{
      activity: activity,
      group: group,
      owner: owner,
      project: project,
      organisation: organisation
    } do
      assert {:ok, activities} =
               Activity.by_group_id_and_project_id(
                 %{group_id: group.id, project_id: project.id},
                 actor: owner,
                 tenant: organisation
               )

      assert length(activities) == 1
      assert hd(activities).id == activity.id
    end

    test "returns activities for specific group and project for an authorized user", %{
      authorized_user: authorized_user,
      activity: activity,
      group: group,
      project: project,
      organisation: organisation
    } do
      assert {:ok, activities} =
               Activity.by_group_id_and_project_id(
                 %{group_id: group.id, project_id: project.id},
                 actor: authorized_user,
                 tenant: organisation
               )

      assert length(activities) == 1
      assert hd(activities).id == activity.id
    end

    test "does not return activities for specific group and project for an unauthorized user",
         %{
           group: group,
           project: project,
           organisation: organisation,
           user: user
         } do
      assert {:ok, activities} =
               Activity.by_group_id_and_project_id(
                 %{group_id: group.id, project_id: project.id},
                 actor: user,
                 tenant: organisation
               )

      assert Enum.empty?(activities)
    end
  end

  describe "move_up/2" do
    setup %{group: group, project: project} do
      {:ok, activity1} =
        create_activity(%{
          name: "Activity 1",
          group_id: group.id,
          project_id: project.id,
          color_code: "#FF0001",
          slug: "activity-1"
        })

      {:ok, activity2} =
        create_activity(%{
          name: "Activity 2",
          group_id: group.id,
          project_id: project.id,
          color_code: "#FF0002",
          slug: "activity-2"
        })

      %{activity1: activity1, activity2: activity2}
    end

    test "organisation owner can move an activity up in position", %{
      activity1: activity1,
      activity2: activity2,
      owner: owner,
      organisation: organisation
    } do
      assert {:ok, moved_activity} =
               Activity.move_up(activity2, actor: owner, tenant: organisation)

      assert moved_activity.position == 1

      {:ok, updated_activity1} = Activity.by_id(activity1.id, actor: owner, tenant: organisation)
      assert updated_activity1.position == 2
    end

    test "authorized user can move an activity up in position", %{
      authorized_user: authorized_user,
      activity1: activity1,
      activity2: activity2,
      organisation: organisation
    } do
      assert {:ok, moved_activity} =
               Activity.move_up(activity2, actor: authorized_user, tenant: organisation)

      assert moved_activity.position == 1

      {:ok, updated_activity1} =
        Activity.by_id(activity1.id, actor: authorized_user, tenant: organisation)

      assert updated_activity1.position == 2
    end

    test "unauthorized user cannot move an activity up in position", %{
      activity2: activity2,
      organisation: organisation,
      user: user
    } do
      assert {:error, %Ash.Error.Forbidden{}} =
               Activity.move_up(activity2, actor: user, tenant: organisation)
    end

    test "does nothing when activity is at top position", %{
      activity1: activity1,
      owner: owner,
      organisation: organisation
    } do
      assert {:ok, unchanged_activity} =
               Activity.move_up(activity1, actor: owner, tenant: organisation)

      assert unchanged_activity.position == 1
    end
  end

  describe "move_down/2" do
    setup %{group: group, project: project} do
      {:ok, activity2} =
        create_activity(%{
          name: "Activity 1",
          group_id: group.id,
          project_id: project.id,
          color_code: "#FF0001",
          slug: "activity-1"
        })

      {:ok, activity1} =
        create_activity(%{
          name: "Activity 2",
          group_id: group.id,
          project_id: project.id,
          color_code: "#FF0002",
          slug: "activity-2"
        })

      %{activity1: activity1, activity2: activity2}
    end

    test "organisation owner can move an activity down in position", %{
      activity1: activity1,
      activity2: activity2,
      owner: owner,
      organisation: organisation
    } do
      assert {:ok, moved_activity} =
               Activity.move_down(activity2, actor: owner, tenant: organisation)

      assert moved_activity.position == 2

      {:ok, updated_activity1} = Activity.by_id(activity1.id, actor: owner, tenant: organisation)
      assert updated_activity1.position == 1
    end

    test "authorized user can move an activity down in position", %{
      authorized_user: authorized_user,
      activity1: activity1,
      activity2: activity2,
      organisation: organisation
    } do
      assert {:ok, moved_activity} =
               Activity.move_down(activity2, actor: authorized_user, tenant: organisation)

      assert moved_activity.position == 2

      {:ok, updated_activity1} =
        Activity.by_id(activity1.id, actor: authorized_user, tenant: organisation)

      assert updated_activity1.position == 1
    end

    test "unauthorized user cannot move an activity down in position", %{
      activity2: activity2,
      organisation: organisation,
      user: user
    } do
      assert {:error, %Ash.Error.Forbidden{}} =
               Activity.move_down(activity2, actor: user, tenant: organisation)
    end

    test "does nothing when activity is at bottom position", %{
      activity1: activity1,
      owner: owner,
      organisation: organisation
    } do
      assert {:ok, unchanged_activity} =
               Activity.move_down(activity1, actor: owner, tenant: organisation)

      assert unchanged_activity.position == 2
    end
  end
end