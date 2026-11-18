defmodule TrackMyJobExWeb.Router do
  use TrackMyJobExWeb, :router

  import TrackMyJobExWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TrackMyJobExWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Other scopes may use custom stacks.
  # scope "/api", TrackMyJobExWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:track_my_job_ex, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: TrackMyJobExWeb.Telemetry
    end
  end

  ## Authentication routes

  # Health checks are deliberately unauthenticated and outside the browser
  # pipeline so they do not create sessions or require CSRF tokens.
  scope "/", TrackMyJobExWeb do
    get "/health", HealthController, :index
  end

  # Login is public; logout is a controller route that only makes sense for
  # authenticated users.
  scope "/", TrackMyJobExWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{TrackMyJobExWeb.UserAuth, :mount_current_scope}] do
      live "/users/log-in", UserLive.Login, :new
    end

    post "/users/log-in", UserSessionController, :create
  end

  scope "/", TrackMyJobExWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{TrackMyJobExWeb.UserAuth, :require_authenticated}] do
      live "/", DashboardLive
      live "/applications", ApplicationLive.Index, :index
      live "/applications/new", ApplicationLive.New, :new
      live "/applications/:id/edit", ApplicationLive.Edit, :edit
      live "/applications/:id", ApplicationLive.Show, :show
      live "/resumes", ResumeLive.Index, :index
      live "/resumes/new", ResumeLive.New, :new
      live "/resumes/:id/edit", ResumeLive.Edit, :edit
      live "/resumes/:id", ResumeLive.Show, :show
      live "/tags", TagLive.Index, :index
    end

    delete "/users/log-out", UserSessionController, :delete
  end
end
