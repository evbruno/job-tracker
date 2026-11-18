defmodule TrackMyJobExWeb.UI do
  @moduledoc """
  Presentation components shared across the application screens.

  These components hold no business logic: they map already-authorized data to
  markup. Status families are a display concern, so the mapping from a status
  slug to a colour family lives here rather than in a context.
  """

  use Phoenix.Component

  import TrackMyJobExWeb.CoreComponents, only: [icon: 1]

  @status_families %{
    "interested" => "early",
    "applied" => "early",
    "screening" => "process",
    "interview" => "process",
    "technical_interview" => "process",
    "final_interview" => "process",
    "offer" => "positive",
    "accepted" => "positive",
    "declined" => "negative",
    "rejected" => "negative",
    "withdrawn" => "negative",
    "failed" => "negative",
    "on_hold" => "paused"
  }

  @doc """
  Returns the colour family for a status slug.

  Unknown slugs fall back to the neutral "early" family so the status name is
  still legible if the seeded list ever grows.
  """
  def status_family(slug) when is_binary(slug), do: Map.get(@status_families, slug, "early")
  def status_family(_slug), do: "early"

  @doc """
  Renders a status pill: a family-coloured dot followed by the status name.

  The name is always rendered as text; colour alone never carries the meaning.
  """
  attr :status, :map, required: true
  attr :id, :string, default: nil
  attr :name_id, :string, default: nil

  def status_badge(assigns) do
    assigns = assign(assigns, :family, status_family(assigns.status.slug))

    ~H"""
    <span id={@id} class="status-pill" data-family={@family}>
      <span class="status-dot" aria-hidden="true"></span>
      <span id={@name_id}>{@status.name}</span>
    </span>
    """
  end

  @doc """
  Renders the 3px status-family edge shown on application rows and timeline dots.
  """
  attr :slug, :string, required: true
  attr :class, :any, default: nil

  def status_marker(assigns) do
    assigns = assign(assigns, :family, status_family(assigns.slug))

    ~H"""
    <span class={@class} data-family={@family} aria-hidden="true"></span>
    """
  end

  @doc """
  Returns whether an id is in a list of selected ids.

  Lets checkbox chips decide their checked state without turning the selection
  into a set in the template.
  """
  def selected?(selected_ids, id) do
    Enum.any?(selected_ids, fn selected -> to_string(selected) == to_string(id) end)
  end

  @doc """
  Renders a tag as a small neutral chip.
  """
  attr :name, :string, required: true
  attr :id, :string, default: nil

  def tag_chip(assigns) do
    ~H"""
    <span
      id={@id}
      class="inline-flex items-center rounded border border-rule bg-canvas px-1.5 py-px text-xs text-ink-muted"
    >
      {@name}
    </span>
    """
  end

  @doc """
  Renders an empty state with a title, an explanation, and one action.

  Used for both "nothing here yet" and "nothing matches" so the two states read
  consistently and always say what to do next.
  """
  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :icon, :string, default: "hero-inbox"
  slot :inner_block, required: true
  slot :action

  def empty_state(assigns) do
    ~H"""
    <div id={@id} class="rounded border border-dashed border-rule bg-surface px-5 py-10 text-center">
      <.icon name={@icon} class="mx-auto size-6 text-ink-muted" />
      <h2 class="mt-3 text-base font-semibold text-ink">{@title}</h2>
      <p class="mx-auto mt-1 max-w-sm text-sm text-ink-muted">{render_slot(@inner_block)}</p>
      <div :if={@action != []} class="mt-4 flex justify-center gap-2">
        {render_slot(@action)}
      </div>
    </div>
    """
  end

  @doc """
  Renders a confirmation modal for a destructive action.

  The modal is server-backed: the page assigns the record being deleted and
  renders this component. `confirm_event` and `cancel_event` are LiveView event
  names handled by the calling LiveView.
  """
  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :confirm_label, :string, default: "Delete"
  attr :confirm_event, :string, required: true

  attr :confirm_value, :any,
    default: nil,
    doc: "optional phx-value-id sent with the confirm event"

  attr :cancel_event, :string, default: "cancel_delete"
  slot :inner_block, required: true

  def confirm_modal(assigns) do
    ~H"""
    <div id={@id} class="fixed inset-0 z-50 flex items-end justify-center sm:items-center sm:p-4">
      <div
        class="absolute inset-0 bg-ink/45"
        phx-click={@cancel_event}
        aria-hidden="true"
      >
      </div>
      <div
        id={"#{@id}-dialog"}
        role="dialog"
        aria-modal="true"
        aria-labelledby={"#{@id}-title"}
        data-cancel-event={@cancel_event}
        phx-hook=".Modal"
        class="modal-panel relative w-full rounded-t-md border border-rule bg-surface shadow-xl sm:max-w-md sm:rounded-md"
      >
        <div class="px-5 pt-5">
          <h2 id={"#{@id}-title"} class="text-base font-semibold text-ink">{@title}</h2>
          <div class="mt-2 text-sm text-ink-muted">{render_slot(@inner_block)}</div>
        </div>
        <div class="mt-5 flex flex-col-reverse gap-2 border-t border-rule bg-canvas px-5 py-3 sm:flex-row sm:justify-end">
          <button
            type="button"
            id={"#{@id}-cancel"}
            phx-click={@cancel_event}
            data-autofocus
            class="btn btn-ghost btn-sm"
          >
            Cancel
          </button>
          <button
            type="button"
            id={"#{@id}-confirm"}
            phx-click={@confirm_event}
            phx-value-id={@confirm_value}
            class="btn btn-error btn-sm text-white"
          >
            {@confirm_label}
          </button>
        </div>

        <script :type={Phoenix.LiveView.ColocatedHook} name=".Modal">
          export default {
            mounted() {
              this.previouslyFocused = document.activeElement
              this.onKeydown = (event) => {
                if (event.key === "Escape") {
                  event.preventDefault()
                  this.pushEvent(this.el.dataset.cancelEvent || "cancel_delete", {})
                  return
                }
                if (event.key !== "Tab") return

                const focusable = this.el.querySelectorAll(
                  'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
                )
                if (focusable.length === 0) return

                const first = focusable[0]
                const last = focusable[focusable.length - 1]
                if (event.shiftKey && document.activeElement === first) {
                  event.preventDefault()
                  last.focus()
                } else if (!event.shiftKey && document.activeElement === last) {
                  event.preventDefault()
                  first.focus()
                }
              }

              document.addEventListener("keydown", this.onKeydown)
              const target =
                this.el.querySelector("[data-autofocus]") ||
                this.el.querySelector("button")
              if (target) target.focus()
            },
            destroyed() {
              document.removeEventListener("keydown", this.onKeydown)
              if (this.previouslyFocused) this.previouslyFocused.focus()
            }
          }
        </script>
      </div>
    </div>
    """
  end
end
