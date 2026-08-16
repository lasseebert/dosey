defmodule DoseyWeb.AppController do
  use DoseyWeb, :controller

  def index(conn, _params) do
    render(conn, :index)
  end
end
