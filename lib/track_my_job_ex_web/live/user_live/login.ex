defmodule TrackMyJobExWeb.UserLive.Login do
  use TrackMyJobExWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto grid max-w-md gap-5 py-6 sm:py-12">
        <div>
          <h1 class="text-2xl font-semibold tracking-tight text-ink">Log in</h1>
          <p class="mt-1 text-sm text-ink-muted">
            Accounts are provisioned by an administrator. Contact them if you
            need access.
          </p>
        </div>

        <div class="rounded border border-rule bg-surface">
          <.form
            for={@form}
            id="login_form"
            action={~p"/users/log-in"}
            phx-submit="submit"
            phx-trigger-action={@trigger_submit}
            class="flex flex-col gap-4 px-4 py-5 sm:px-5"
          >
            <.input
              field={@form[:email]}
              type="email"
              label="Email"
              autocomplete="username"
              spellcheck="false"
              required
              phx-mounted={JS.focus()}
            />
            <.input
              field={@form[:password]}
              type="password"
              label="Password"
              autocomplete="current-password"
              spellcheck="false"
              required
            />
            <button
              type="submit"
              id="login-submit"
              class="btn btn-primary w-full"
              phx-disable-with="Logging in..."
            >
              Log in
            </button>
          </.form>
        </div>

        <p class="text-xs text-ink-muted">
          Sessions last up to 14 days. Log out from the header when you are on a
          shared computer.
        </p>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, push_navigate(socket, to: ~p"/")}
  end

  def mount(_params, _session, socket) do
    email = Phoenix.Flash.get(socket.assigns.flash, :email) || ""

    form = to_form(%{"email" => email}, as: "user")

    {:ok, assign(socket, form: form, trigger_submit: false)}
  end

  @impl true
  def handle_event("submit", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end
end
