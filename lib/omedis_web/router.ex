defmodule OmedisWeb.Router do
  use OmedisWeb, :router
  use AshAuthentication.Phoenix.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {OmedisWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :load_from_bearer
  end

  scope "/", OmedisWeb do
    pipe_through :browser

    get "/", PageController, :home

    live "/login", LoginLive, :index
    live "/register", RegisterLive, :index

    sign_out_route(AuthController, "/auth/user/sign-out")
    auth_routes_for(Omedis.Accounts.User, to: AuthController)

    reset_route([])

    ash_authentication_live_session :authentication_required,
      on_mount: {OmedisWeb.LiveUserAuth, :live_user_required} do
      live "/tenants", TenantLive.Index, :index
      live "/tenants/new", TenantLive.Index, :new
      live "/tenants/:id/edit", TenantLive.Index, :edit

      live "/tenants/:tenant_id/log_categories", LogCategoryLive.Index, :index
      live "/tenants/:tenant_id/log_categories/new", LogCategoryLive.Index, :new
      live "/tenants/:tenant_id/log_categories/:id", LogCategoryLive.Show, :show
      live "/tenants/:tenant_id/log_categories/:id/edit", LogCategoryLive.Index, :edit
      live "/tenants/:tenant_id/log_categories/:id/show/edit", LogCategoryLive.Show, :edit
      live "/tenants/:id", TenantLive.Show, :show
      live "/tenants/:id/show/edit", TenantLive.Show, :edit

      # live "/log_categories", LogCategoryLive.Index, :index
      # live "/log_categories/new", LogCategoryLive.Index, :new
      # live "/log_categories/:id/edit", LogCategoryLive.Index, :edit

      # live "/log_categories/:id", LogCategoryLive.Show, :show
      # live "/log_categories/:id/show/edit", LogCategoryLive.Show, :edit
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", OmedisWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:omedis, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: OmedisWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
