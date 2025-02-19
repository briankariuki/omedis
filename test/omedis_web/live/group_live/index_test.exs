defmodule OmedisWeb.GroupLive.IndexTest do
  use OmedisWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Omedis.Fixtures
  import Omedis.TestUtils

  setup do
    {:ok, owner} = create_user()
    {:ok, another_user} = create_user()
    organisation = fetch_users_organisation(owner.id)
    organisation_2 = fetch_users_organisation(another_user.id)

    %{
      another_user: another_user,
      owner: owner,
      organisation_2: organisation_2,
      organisation: organisation
    }
  end

  describe "/organisations/:slug/groups" do
    test "list groups with pagination", %{
      another_user: another_user,
      conn: conn,
      owner: owner,
      organisation: organisation,
      organisation_2: organisation_2
    } do
      Enum.each(3..15, fn i ->
        {:ok, group} =
          create_group(organisation, %{
            user_id: owner.id,
            name: "Group #{i}"
          })

        create_group_membership(organisation, %{user_id: owner.id, group_id: group.id})

        create_access_right(organisation, %{
          resource_name: "Group",
          group_id: group.id,
          read: true
        })
      end)

      Enum.each(16..30, fn i ->
        {:ok, group} =
          create_group(organisation, %{
            user_id: owner.id,
            name: "Group #{i}"
          })

        create_group_membership(organisation, %{user_id: owner.id, group_id: group.id})

        create_access_right(organisation, %{
          resource_name: "Group",
          group_id: group.id,
          read: false
        })
      end)

      Enum.each(31..40, fn i ->
        {:ok, group} =
          create_group(organisation_2, %{
            user_id: another_user.id,
            name: "Group #{i}"
          })

        create_group_membership(organisation, %{user_id: another_user.id, group_id: group.id})

        create_access_right(organisation_2, %{
          resource_name: "Group",
          group_id: group.id,
          read: false
        })
      end)

      {:ok, view, html} =
        conn
        |> log_in_user(owner)
        |> live(~p"/organisations/#{organisation}/groups")

      assert html =~ "Listing Groups"
      assert html =~ "New Group"
      assert html =~ "Group 3"
      assert html =~ "Group 10"
      refute html =~ "Group 11"

      assert view |> element("nav[aria-label=Pagination]") |> has_element?()

      view
      |> element("nav[aria-label=Pagination] a", "3")
      |> render_click()

      # # There is no next page
      refute view |> element("nav[aria-label=Pagination] a", "4") |> has_element?()

      html = render(view)
      assert html =~ "Group 21"
      refute html =~ "Group 16"
      refute html =~ "Group 37"
    end

    test "edit and delete actions are hidden is user has no rights to destroy or update a group",
         %{
           conn: conn,
           owner: owner
         } do
      {:ok, organisation} = create_organisation()

      {:ok, group} =
        create_group(organisation, %{
          user_id: owner.id,
          name: "Group 1"
        })

      create_group_membership(organisation, %{user_id: owner.id, group_id: group.id})

      create_access_right(organisation, %{
        resource_name: "Organisation",
        group_id: group.id,
        read: true,
        destroy: false,
        update: false
      })

      create_access_right(organisation, %{
        resource_name: "Group",
        group_id: group.id,
        read: true,
        destroy: false,
        update: false
      })

      {:ok, view, html} =
        conn
        |> log_in_user(owner)
        |> live(~p"/organisations/#{organisation}/groups")

      refute view |> element("#edit-group-#{group.id}") |> has_element?()
      refute view |> element("#delete-group-#{group.id}") |> has_element?()

      assert html =~ group.name
    end

    test "authorized user can delete a group", %{
      conn: conn,
      owner: owner,
      organisation: organisation
    } do
      {:ok, group} =
        create_group(organisation, %{
          user_id: owner.id,
          name: "Group 1"
        })

      create_group_membership(organisation, %{user_id: owner.id, group_id: group.id})

      create_access_right(organisation, %{
        resource_name: "Group",
        group_id: group.id,
        read: true,
        destroy: true
      })

      {:ok, view, _html} =
        conn
        |> log_in_user(owner)
        |> live(~p"/organisations/#{organisation}/groups")

      assert view
             |> element("#delete-group-#{group.id}")
             |> has_element?()

      assert {:ok, conn} =
               view
               |> element("#delete-group-#{group.id}")
               |> render_click()
               |> follow_redirect(conn)

      html = html_response(conn, 200)

      refute html =~ group.name
    end

    test "authorized user can edit a group", %{
      conn: conn,
      owner: owner,
      organisation: organisation
    } do
      {:ok, group} =
        create_group(organisation, %{
          user_id: owner.id,
          name: "Group 1"
        })

      create_group_membership(organisation, %{user_id: owner.id, group_id: group.id})

      create_access_right(organisation, %{
        resource_name: "Group",
        group_id: group.id,
        read: true,
        update: true
      })

      {:ok, view, _html} =
        conn
        |> log_in_user(owner)
        |> live(~p"/organisations/#{organisation}/groups")

      assert view
             |> element("#edit-group-#{group.id}")
             |> has_element?()

      assert view
             |> element("#edit-group-#{group.id}")
             |> render_click() =~ "Edit Group"

      assert view
             |> form("#group-form", group: %{name: "New Group Name"})
             |> render_submit()

      assert_patch(view, ~p"/organisations/#{organisation}/groups")

      html = render(view)
      assert html =~ "Group updated successfully"
      assert html =~ "New Group Name"
    end
  end

  describe "/organisations/:slug/groups/:slug/edit" do
    test "can't edit a group if not authorized", %{
      conn: conn,
      owner: owner
    } do
      {:ok, organisation} = create_organisation()

      {:ok, group} =
        create_group(organisation, %{
          user_id: owner.id,
          name: "Group 1"
        })

      create_group_membership(organisation, %{user_id: owner.id, group_id: group.id})

      create_access_right(organisation, %{
        resource_name: "Organisation",
        group_id: group.id,
        read: true,
        update: false
      })

      create_access_right(organisation, %{
        resource_name: "Group",
        group_id: group.id,
        read: true,
        update: false
      })

      {:error, {:redirect, %{to: path, flash: flash}}} =
        conn
        |> log_in_user(owner)
        |> live(~p"/organisations/#{organisation}/groups/#{group}/edit")

      assert path == ~p"/organisations/#{organisation}/groups"
      assert flash["error"] == "You are not authorized to access this page"
    end
  end
end
