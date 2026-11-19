defmodule TrackMyJobExWeb.ApplicationLive.Index do
  @moduledoc """
  Lists the current user's job applications with search, filters, sorting, and
  pagination.

  All listing state lives in the URL query string, so refreshing or bookmarking
  a page restores the same view. Queries are built by
  `TrackMyJobEx.JobApplications`.
  """

  use TrackMyJobExWeb, :live_view

  alias TrackMyJobEx.JobApplications
  alias TrackMyJobExWeb.Formatters

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Applications")
     |> assign(:pending_delete, nil)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, load_applications(socket, params)}
  end

  @impl true
  def handle_event("filter", params, socket) do
    filters = JobApplications.normalize_filters(socket.assigns.current_scope, params)

    {:noreply, push_patch(socket, to: applications_path(filters, 1))}
  end

  def handle_event("toggle_direction", _params, socket) do
    filters = %{
      socket.assigns.filters
      | direction: opposite_direction(socket.assigns.filters.direction)
    }

    {:noreply, push_patch(socket, to: applications_path(filters, 1))}
  end

  def handle_event("prompt_delete", %{"id" => id}, socket) do
    case JobApplications.get_application(socket.assigns.current_scope, id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Application not found.")}

      application ->
        {:noreply, assign(socket, :pending_delete, application)}
    end
  end

  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, :pending_delete, nil)}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    case JobApplications.get_application(scope, id) do
      nil ->
        {:noreply,
         assign(socket, :pending_delete, nil) |> put_flash(:error, "Application not found.")}

      application ->
        {:ok, _deleted} = JobApplications.delete_application(scope, application)

        {:noreply,
         socket
         |> assign(:pending_delete, nil)
         |> put_flash(:info, "Application deleted.")
         |> reload_current_page()}
    end
  end

  defp load_applications(socket, params) do
    scope = socket.assigns.current_scope
    result = JobApplications.list_applications_filtered(scope, params)
    options = JobApplications.filter_options(scope)
    {range_start, range_end} = page_range(result.page, result.page_size, result.total_count)

    socket
    |> assign(:filters, result.filters)
    |> assign(:filters_active?, result.filtered?)
    |> assign(:filter_options, options)
    |> assign(:filter_chips, filter_chips(result.filters, options))
    |> assign(:page, result.page)
    |> assign(:total_pages, result.total_pages)
    |> assign(:total_count, result.total_count)
    |> assign(:page_size, result.page_size)
    |> assign(:range_start, range_start)
    |> assign(:range_end, range_end)
    |> assign(:empty_state, empty_state_for(result))
    |> stream(:applications, result.entries, reset: true)
  end

  defp reload_current_page(socket) do
    params =
      socket.assigns.filters
      |> filters_to_params()
      |> Map.put("page", socket.assigns.page)

    load_applications(socket, params)
  end

  defp empty_state_for(%{total_count: 0, filtered?: true}), do: :no_matches
  defp empty_state_for(%{total_count: 0}), do: :no_applications
  defp empty_state_for(_result), do: :none

  defp page_range(_page, _page_size, 0), do: {nil, nil}

  defp page_range(page, page_size, total_count) do
    {(page - 1) * page_size + 1, min(page * page_size, total_count)}
  end

  # Every active filter becomes a dismissible chip. Each chip links to the same
  # listing with that one filter removed, so URL state stays canonical.
  defp filter_chips(filters, options) do
    status_name =
      Enum.find_value(options.statuses, fn status ->
        status.slug == filters.status && status.name
      end)

    tag_chips =
      for tag <- options.tags, tag.id in filters.tags do
        {"filter-chip-tag-#{tag.id}", "Tag: #{tag.name}",
         %{filters | tags: filters.tags -- [tag.id]}}
      end

    [
      {filters.q, "filter-chip-search", "Search: “#{filters.q}”", %{filters | q: nil}},
      {status_name, "filter-chip-status", "Status: #{status_name}", %{filters | status: nil}},
      {filters.company, "filter-chip-company", "Company: #{filters.company}",
       %{filters | company: nil}},
      {filters.recruiter, "filter-chip-recruiter", "Recruiter: #{filters.recruiter}",
       %{filters | recruiter: nil}}
    ]
    |> Enum.filter(fn {present, _id, _label, _filters} -> present end)
    |> Enum.map(fn {_present, id, label, next} ->
      %{id: id, label: label, path: applications_path(next, 1)}
    end)
    |> Kernel.++(
      Enum.map(tag_chips, fn {id, label, next} ->
        %{id: id, label: label, path: applications_path(next, 1)}
      end)
    )
  end

  defp archived_query_param(:archived), do: "archived"
  defp archived_query_param(:all), do: "all"
  defp archived_query_param(_), do: nil

  defp filters_to_params(filters) do
    %{
      "q" => filters.q,
      "status" => filters.status,
      "company" => filters.company,
      "recruiter" => filters.recruiter,
      "tags" => Enum.map(filters.tags, &to_string/1),
      "archived" => archived_filter_value(filters.archived),
      "sort" => filters.sort,
      "direction" => filters.direction
    }
  end

  defp archived_filter_value(:archived), do: "archived"
  defp archived_filter_value(:all), do: "all"
  defp archived_filter_value(_), do: ""

  defp applications_path(filters, page) do
    params =
      %{}
      |> put_query_param("q", filters.q)
      |> put_query_param("status", filters.status)
      |> put_query_param("company", filters.company)
      |> put_query_param("recruiter", filters.recruiter)
      |> put_query_param("tags", Enum.map(filters.tags, &to_string/1))
      |> put_query_param("archived", archived_query_param(filters.archived))
      |> put_query_param("sort", sort_query_value(filters.sort))
      |> put_query_param("direction", direction_query_value(filters.direction))
      |> put_query_param("page", page_query_value(page))

    case params do
      params when map_size(params) == 0 -> ~p"/applications"
      params -> ~p"/applications?#{params}"
    end
  end

  defp put_query_param(params, _key, nil), do: params
  defp put_query_param(params, _key, ""), do: params
  defp put_query_param(params, _key, []), do: params
  defp put_query_param(params, key, value), do: Map.put(params, key, value)

  defp sort_query_value("created"), do: nil
  defp sort_query_value(sort), do: sort

  defp direction_query_value("desc"), do: nil
  defp direction_query_value(direction), do: direction

  defp page_query_value(1), do: nil
  defp page_query_value(page), do: page

  defp opposite_direction("asc"), do: "desc"
  defp opposite_direction(_direction), do: "asc"

  defp direction_label(%{sort: "updated", direction: "asc"}), do: "Least recently updated"
  defp direction_label(%{sort: "updated"}), do: "Recently updated"
  defp direction_label(%{direction: "asc"}), do: "Oldest first"
  defp direction_label(_filters), do: "Newest first"

  defp direction_icon(%{direction: "asc"}), do: "hero-arrow-up"
  defp direction_icon(_filters), do: "hero-arrow-down"

  defp status_options(%{statuses: statuses}), do: Enum.map(statuses, &{&1.name, &1.slug})
  defp company_options(%{companies: companies}), do: Enum.map(companies, &{&1, &1})
  defp recruiter_options(%{recruiters: recruiters}), do: Enum.map(recruiters, &{&1, &1})
end
