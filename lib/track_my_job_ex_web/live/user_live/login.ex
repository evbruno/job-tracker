defmodule TrackMyJobExWeb.UserLive.Login do
  use TrackMyJobExWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto grid max-w-md gap-6 py-8 sm:py-14">
        <div class="text-center">
          <span class="mx-auto inline-flex items-center rounded-full bg-[#e7ecff] px-3 py-1 text-xs font-bold tracking-[0.16em] text-cobalt">
            BETA ACCESS
          </span>
          <h1 class="mt-4 text-3xl font-semibold tracking-tight text-ink">Welcome back</h1>
          <p class="mt-2 text-sm leading-6 text-ink-muted">
            Sign in to pick up where your job search left off.
          </p>
        </div>

        <div class="rounded-xl border border-rule bg-surface shadow-sm">
          <.form
            for={@form}
            id="login_form"
            action={~p"/users/log-in"}
            phx-submit="submit"
            phx-trigger-action={@trigger_submit}
            class="flex flex-col gap-5 p-5 sm:p-7"
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
              class="btn btn-primary mt-1 min-h-12 w-full rounded-lg text-sm font-semibold shadow-sm transition-colors"
              phx-disable-with="Logging in..."
            >
              Log in
            </button>
          </.form>
        </div>

        <p class="text-center text-xs leading-5 text-ink-muted">
          Accounts are provisioned by an administrator. Contact them if you need access.
          Sessions last up to 14 days; log out from the header on shared computers.
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
