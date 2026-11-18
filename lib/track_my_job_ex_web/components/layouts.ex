defmodule TrackMyJobExWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use TrackMyJobExWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://phoenix.hexdocs.pm/scopes.html)"

  attr :active, :atom,
    default: nil,
    doc: "the navigation section to highlight: :dashboard, :applications, :tags, or nil"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="flex min-h-screen flex-col bg-canvas">
      <header class="sticky top-0 z-40 border-b border-rule bg-surface">
        <div class="mx-auto flex w-full max-w-5xl flex-wrap items-center gap-x-6 gap-y-1.5 px-4 py-2 sm:px-6 lg:px-8">
          <.link
            navigate={~p"/"}
            class="flex shrink-0 items-center gap-2 text-[15px] font-semibold tracking-tight text-ink"
          >
            <.icon name="hero-briefcase" class="size-5" />
            <span>Job Tracker</span>
          </.link>

          <nav
            :if={@current_scope && @current_scope.user}
            id="main-nav"
            aria-label="Main navigation"
            class="order-last w-full sm:order-none sm:w-auto"
          >
            <ul class="flex items-center gap-5 text-sm">
              <li>
                <.link
                  navigate={~p"/"}
                  class={nav_link(@active == :dashboard)}
                  aria-current={@active == :dashboard && "page"}
                >
                  Dashboard
                </.link>
              </li>
              <li>
                <.link
                  navigate={~p"/applications"}
                  id="nav-applications"
                  class={nav_link(@active == :applications)}
                  aria-current={@active == :applications && "page"}
                >
                  Applications
                </.link>
              </li>
              <li>
                <.link
                  navigate={~p"/tags"}
                  id="nav-tags"
                  class={nav_link(@active == :tags)}
                  aria-current={@active == :tags && "page"}
                >
                  Tags
                </.link>
              </li>
            </ul>
          </nav>

          <div class="ml-auto flex items-center gap-3">
            <span
              :if={@current_scope && @current_scope.user}
              id="current-user-email"
              class="hidden max-w-56 truncate font-mono text-xs text-ink-muted md:block"
            >
              {@current_scope.user.email}
            </span>
            <.link
              :if={@current_scope && @current_scope.user}
              href={~p"/users/log-out"}
              method="delete"
              id="log-out"
              class="text-sm text-ink-muted hover:text-ink"
            >
              Log out
            </.link>
          </div>
        </div>
      </header>

      <main class="mx-auto w-full max-w-5xl flex-1 px-4 py-6 sm:px-6 sm:py-8 lg:px-8">
        {render_slot(@inner_block)}
      </main>

      <footer class="border-t border-rule">
        <div class="mx-auto w-full max-w-5xl px-4 py-4 text-xs text-ink-muted sm:px-6 lg:px-8">
          Job Tracker — applications, tags, and status history.
        </div>
      </footer>

      <.flash_group flash={@flash} />
    </div>
    """
  end

  defp nav_link(true) do
    "border-b-2 border-cobalt pb-0.5 font-medium text-ink"
  end

  defp nav_link(false) do
    "border-b-2 border-transparent pb-0.5 text-ink-muted hover:border-rule hover:text-ink"
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={
          show(".phx-client-error #client-error")
          |> JS.remove_attribute("hidden", to: ".phx-client-error #client-error")
        }
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={
          show(".phx-server-error #server-error")
          |> JS.remove_attribute("hidden", to: ".phx-server-error #server-error")
        }
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end
end
