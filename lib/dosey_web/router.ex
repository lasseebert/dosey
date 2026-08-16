defmodule DoseyWeb.Router do
  use DoseyWeb, :router

  import DoseyWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {DoseyWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :redirect_if_authenticated do
    plug :redirect_if_user_is_authenticated
  end

  pipeline :authenticated do
    plug :require_authenticated_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", DoseyWeb do
    pipe_through :browser

    get "/", PageController, :home
    delete "/logout", UserSessionController, :delete
    post "/logout", UserSessionController, :delete
  end

  scope "/", DoseyWeb do
    pipe_through [:browser, :redirect_if_authenticated]

    get "/login", UserSessionController, :new
    post "/login", UserSessionController, :create
  end

  scope "/", DoseyWeb do
    pipe_through [:browser, :authenticated]

    get "/app", AppController, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api", DoseyWeb do
  #   pipe_through :api
  # end
end
