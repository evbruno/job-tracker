defmodule TrackMyJobExWeb.PageController do
  use TrackMyJobExWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
