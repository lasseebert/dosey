defmodule DoseyWeb.PageController do
  use DoseyWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
