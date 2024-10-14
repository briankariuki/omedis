defmodule OmedisWeb.RegisterTest do
  use OmedisWeb.ConnCase
  alias Omedis.Accounts.Tenant
  alias Omedis.Accounts.User

  import Phoenix.LiveViewTest

  @valid_registration_params %{
    "first_name" => "John",
    "last_name" => "Doe",
    "email" => "test@gmail.com",
    "password" => "12345678",
    "gender" => "Male",
    "birthdate" => "1990-01-01",
    "lang" => "en",
    "daily_start_at" => "09:00:00",
    "daily_end_at" => "17:00:00"
  }

  @valid_tenant_params %{
    name: "Test Tenant",
    street: "123 Test St",
    zip_code: "12345",
    city: "Test City",
    country: "Test Country",
    slug: "test-tenant"
  }

  setup do
    {:ok, tenant} =
      Ash.Changeset.new(Tenant)
      |> Ash.Changeset.for_create(:create, @valid_tenant_params)
      |> Ash.create()

    {:ok, %{tenant: tenant}}
  end

  describe "Tests the Registration flow" do
    test "The registration form is displayed", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/register")

      assert has_element?(view, "#basic_user_sign_up_form")
    end

    test "Form fields are disabled until a tenant is selected", %{conn: conn, tenant: tenant} do
      {:ok, view, _html} = live(conn, "/register")

      assert view |> element("#user_email") |> render() =~ "disabled"

      view
      |> element("#select_tenant")
      |> render_change(tenant: %{id: tenant.id})

      refute view |> element("#user_email") |> render() =~ "disabled"
    end

    test "Once we make changes to the registration form, we see any errors if they are there", %{
      conn: conn,
      tenant: tenant
    } do
      {:ok, view, _html} = live(conn, "/register")

      view
      |> element("#select_tenant")
      |> render_change(tenant: %{id: tenant.id})

      html =
        view
        |> form("#basic_user_sign_up_form", user: %{"password" => "1"})
        |> render_change()

      assert html =~ "length must be greater than or equal to 8"
    end

    test "You can sign in with valid data", %{conn: conn, tenant: tenant} do
      {:ok, view, _html} = live(conn, "/register")

      {:error, _} = User.by_email(@valid_registration_params["email"])

      view
      |> element("#select_tenant")
      |> render_change(tenant: %{id: tenant.id})

      params =
        @valid_registration_params
        |> Map.replace("first_name", "Mary")
        |> Map.replace("email", "test@user.com")

      view
      |> form("#basic_user_sign_up_form", user: params)
      |> render_change()

      sign_up_form = form(view, "#basic_user_sign_up_form", user: params)
      html = render_submit(sign_up_form)

      assert html =~ ~r/phx-trigger-action/

      conn = follow_trigger_action(sign_up_form, conn)

      assert redirected_to(conn) == ~p"/"

      assert response =
               conn
               |> get(~p"/")
               |> html_response(200)

      assert response =~ "Mary"
      refute response =~ "Register"

      assert {:ok, user} = User.by_email("test@user.com")
      assert user.first_name == "Mary"
    end
  end
end
