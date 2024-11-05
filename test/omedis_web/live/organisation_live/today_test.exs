defmodule OmedisWeb.OrganisationLive.TodayTest do
  use OmedisWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup do
    {:ok, owner} = create_user(%{daily_start_at: ~T[08:00:00], daily_end_at: ~T[18:00:00]})
    {:ok, organisation} = create_organisation(%{owner_id: owner.id})
    {:ok, group} = create_group(%{organisation_id: organisation.id})
    {:ok, project} = create_project(%{organisation_id: organisation.id})

    {:ok, log_category} =
      create_log_category(%{group_id: group.id, is_default: true, project_id: project.id})

    {:ok, authorized_user} =
      create_user(%{daily_start_at: ~T[08:00:00], daily_end_at: ~T[18:00:00]})

    {:ok, user} = create_user(%{daily_start_at: ~T[08:00:00], daily_end_at: ~T[18:00:00]})

    {:ok, _} = create_group_user(%{group_id: group.id, user_id: authorized_user.id})

    {:ok, _} =
      create_access_right(%{
        group_id: group.id,
        read: true,
        resource_name: "Organisation",
        organisation_id: organisation.id
      })

    {:ok, _} =
      create_access_right(%{
        group_id: group.id,
        read: true,
        resource_name: "Project",
        organisation_id: organisation.id
      })

    {:ok, _} =
      create_access_right(%{
        group_id: group.id,
        read: true,
        resource_name: "Group",
        organisation_id: organisation.id
      })

    {:ok, _} =
      create_access_right(%{
        group_id: group.id,
        read: true,
        resource_name: "LogCategory",
        organisation_id: organisation.id
      })

    %{
      authorized_user: authorized_user,
      group: group,
      log_category: log_category,
      owner: owner,
      project: project,
      organisation: organisation,
      user: user
    }
  end

  describe "/organisations/:slug/today" do
    alias Omedis.Accounts.LogEntry

    test "organisation owner can create a new log entry", %{
      conn: conn,
      group: group,
      log_category: log_category,
      owner: owner,
      project: project,
      organisation: organisation
    } do
      {:ok, _} =
        create_access_right(%{
          group_id: group.id,
          read: true,
          resource_name: "LogEntry",
          organisation_id: organisation.id,
          write: true
        })

      {:ok, lv, _html} =
        conn
        |> log_in_user(owner)
        |> live(
          ~p"/organisations/#{organisation.slug}/today?group_id=#{group.id}&project_id=#{project.id}"
        )

      assert lv
             |> element("#log-category-#{log_category.id}")
             |> render_click() =~ "active-log-category-#{log_category.id}"

      {:ok, [log_entry]} =
        LogEntry.by_log_category_today(
          %{log_category_id: log_category.id},
          actor: owner,
          tenant: organisation
        )

      assert log_entry.log_category_id == log_category.id
      assert log_entry.user_id == owner.id
      assert log_entry.organisation_id == organisation.id
    end

    test "organisation owner can stop active log entry when selecting same category again", %{
      conn: conn,
      group: group,
      log_category: log_category,
      owner: owner,
      project: project,
      organisation: organisation
    } do
      {:ok, _} =
        create_access_right(%{
          group_id: group.id,
          read: true,
          resource_name: "LogEntry",
          organisation_id: organisation.id,
          write: true
        })

      {:ok, lv, _html} =
        conn
        |> log_in_user(owner)
        |> live(
          ~p"/organisations/#{organisation.slug}/today?group_id=#{group.id}&project_id=#{project.id}"
        )

      # Create a log entry
      assert lv
             |> element("#log-category-#{log_category.id}")
             |> render_click() =~ "active-log-category-#{log_category.id}"

      # Click same category again to stop it
      refute lv
             |> element("#log-category-#{log_category.id}")
             |> render_click() =~ "active-log-category-#{log_category.id}"

      # Verify log entry was stopped (end_at was set)
      {:ok, [log_entry]} =
        LogEntry.by_log_category_today(
          %{log_category_id: log_category.id},
          actor: owner,
          tenant: organisation
        )

      assert log_entry.log_category_id == log_category.id
      assert not is_nil(log_entry.end_at)
    end

    test "organisation owner can switch active log entry by selecting different category", %{
      conn: conn,
      group: group,
      owner: owner,
      project: project,
      organisation: organisation
    } do
      {:ok, _} =
        create_access_right(%{
          group_id: group.id,
          read: true,
          resource_name: "LogEntry",
          organisation_id: organisation.id,
          write: true
        })

      {:ok, log_category_1} =
        create_log_category(%{group_id: group.id, project_id: project.id, name: "Category 1"})

      {:ok, log_category_2} =
        create_log_category(%{group_id: group.id, project_id: project.id, name: "Category 2"})

      {:ok, lv, _html} =
        conn
        |> log_in_user(owner)
        |> live(
          ~p"/organisations/#{organisation.slug}/today?group_id=#{group.id}&project_id=#{project.id}"
        )

      # Start log entry for the first category
      assert lv
             |> element("#log-category-#{log_category_1.id}")
             |> render_click() =~ "active-log-category-#{log_category_1.id}"

      # Switch to second category
      assert lv
             |> element("#log-category-#{log_category_2.id}")
             |> render_click() =~ "active-log-category-#{log_category_2.id}"

      # Verify first log entry was stopped
      {:ok, [entry_1]} =
        LogEntry.by_log_category_today(
          %{log_category_id: log_category_1.id},
          actor: owner,
          tenant: organisation
        )

      assert not is_nil(entry_1.end_at)

      # Verify second log entry is active
      {:ok, entries_2} =
        LogEntry.by_log_category_today(
          %{log_category_id: log_category_2.id},
          actor: owner,
          tenant: organisation
        )

      entry_2 = List.last(entries_2)
      assert is_nil(entry_2.end_at)
    end

    test "authorized user can create a new log entry", %{
      authorized_user: authorized_user,
      conn: conn,
      group: group,
      log_category: log_category,
      project: project,
      organisation: organisation
    } do
      {:ok, _} =
        create_access_right(%{
          group_id: group.id,
          read: true,
          resource_name: "LogEntry",
          organisation_id: organisation.id,
          write: true
        })

      {:ok, lv, _html} =
        conn
        |> log_in_user(authorized_user)
        |> live(
          ~p"/organisations/#{organisation.slug}/today?group_id=#{group.id}&project_id=#{project.id}"
        )

      assert lv
             |> element("#log-category-#{log_category.id}")
             |> render_click() =~ "active-log-category-#{log_category.id}"

      {:ok, [log_entry]} =
        LogEntry.by_log_category_today(
          %{log_category_id: log_category.id},
          actor: authorized_user,
          tenant: organisation
        )

      assert log_entry.log_category_id == log_category.id
      assert log_entry.user_id == authorized_user.id
      assert log_entry.organisation_id == organisation.id
    end

    test "authorized user can stop active log entry when selecting same category again", %{
      authorized_user: authorized_user,
      conn: conn,
      group: group,
      log_category: log_category,
      project: project,
      organisation: organisation
    } do
      {:ok, _} =
        create_access_right(%{
          group_id: group.id,
          read: true,
          resource_name: "LogEntry",
          organisation_id: organisation.id,
          write: true
        })

      {:ok, lv, _html} =
        conn
        |> log_in_user(authorized_user)
        |> live(
          ~p"/organisations/#{organisation.slug}/today?group_id=#{group.id}&project_id=#{project.id}"
        )

      # Create a log entry
      assert lv
             |> element("#log-category-#{log_category.id}")
             |> render_click() =~ "active-log-category-#{log_category.id}"

      # Click same category again to stop it
      refute lv
             |> element("#log-category-#{log_category.id}")
             |> render_click() =~ "active-log-category-#{log_category.id}"

      # Verify log entry was stopped (end_at was set)
      {:ok, [log_entry]} =
        LogEntry.by_log_category_today(
          %{log_category_id: log_category.id},
          actor: authorized_user,
          tenant: organisation
        )

      assert log_entry.log_category_id == log_category.id
      assert not is_nil(log_entry.end_at)
    end

    test "authorized user can switch active log entry by selecting different category", %{
      authorized_user: authorized_user,
      conn: conn,
      group: group,
      project: project,
      organisation: organisation
    } do
      {:ok, _} =
        create_access_right(%{
          group_id: group.id,
          read: true,
          resource_name: "LogEntry",
          organisation_id: organisation.id,
          write: true
        })

      {:ok, log_category_1} =
        create_log_category(%{group_id: group.id, project_id: project.id, name: "Category 1"})

      {:ok, log_category_2} =
        create_log_category(%{group_id: group.id, project_id: project.id, name: "Category 2"})

      {:ok, lv, _html} =
        conn
        |> log_in_user(authorized_user)
        |> live(
          ~p"/organisations/#{organisation.slug}/today?group_id=#{group.id}&project_id=#{project.id}"
        )

      # Start log entry for the first category
      assert lv
             |> element("#log-category-#{log_category_1.id}")
             |> render_click() =~ "active-log-category-#{log_category_1.id}"

      # Switch to second category
      assert lv
             |> element("#log-category-#{log_category_2.id}")
             |> render_click() =~ "active-log-category-#{log_category_2.id}"

      # Verify first log entry was stopped
      {:ok, [entry_1]} =
        LogEntry.by_log_category_today(
          %{log_category_id: log_category_1.id},
          actor: authorized_user,
          tenant: organisation
        )

      assert not is_nil(entry_1.end_at)

      # Verify second log entry is active
      {:ok, entries_2} =
        LogEntry.by_log_category_today(
          %{log_category_id: log_category_2.id},
          actor: authorized_user,
          tenant: organisation
        )

      entry_2 = List.last(entries_2)
      assert is_nil(entry_2.end_at)
    end

    test "unauthorized user cannot create log entries", %{
      conn: conn,
      group: group,
      log_category: log_category,
      project: project,
      organisation: organisation,
      user: unauthorized_user
    } do
      {:ok, group2} = create_group(%{organisation_id: organisation.id})
      {:ok, _} = create_group_user(%{group_id: group2.id, user_id: unauthorized_user.id})

      {:ok, _} =
        create_access_right(%{
          group_id: group2.id,
          read: true,
          resource_name: "Organisation",
          organisation_id: organisation.id
        })

      {:ok, _} =
        create_access_right(%{
          group_id: group2.id,
          read: true,
          resource_name: "Project",
          organisation_id: organisation.id
        })

      {:ok, _} =
        create_access_right(%{
          group_id: group2.id,
          read: true,
          resource_name: "Group",
          organisation_id: organisation.id
        })

      {:ok, _} =
        create_access_right(%{
          group_id: group2.id,
          read: true,
          resource_name: "LogCategory",
          organisation_id: organisation.id
        })

      {:ok, lv, _html} =
        conn
        |> log_in_user(unauthorized_user)
        |> live(
          ~p"/organisations/#{organisation.slug}/today?group_id=#{group.id}&project_id=#{project.id}"
        )

      refute lv
             |> element("#log-category-#{log_category.id}")
             |> render_click() =~ "active-log-category-#{log_category.id}"

      assert {:ok, []} =
               LogEntry.by_log_category_today(
                 %{log_category_id: log_category.id},
                 actor: unauthorized_user,
                 tenant: organisation
               )
    end
  end
end
