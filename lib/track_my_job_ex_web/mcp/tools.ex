defmodule TrackMyJobExWeb.MCP.Tools do
  @moduledoc """
  Handlers for the MCP tools exposed by `TrackMyJobExWeb.MCP.Router`.

  Every handler derives the `%TrackMyJobEx.Accounts.Scope{}` from the
  authenticated MCP session and delegates to the existing scoped contexts.
  Validation, tag ownership, `updated_at` semantics, and the atomic status
  history writes therefore behave exactly as they do in the web interface.

  No handler accepts a `user_id`. Another user's record id is treated as not
  found.
  """

  import Phantom.Tool, only: [error: 1, text: 1]

  alias TrackMyJobEx.Accounts.Scope
  alias TrackMyJobEx.JobApplications
  alias TrackMyJobEx.Resumes
  alias TrackMyJobEx.Tags
  alias TrackMyJobExWeb.MCP.Serializer

  @application_fields ~w[position company_name recruiter_name description job_posting_url]

  @resume_fields ~w[title body email full_name headline phone location linkedin_url github_url portfolio_url]

  @listing_fields ~w[q status company recruiter tags sort direction page]

  ## Applications

  @doc "Lists the caller's applications with search, filters, sorting, and pagination."
  def applications_list(params, session) do
    page =
      JobApplications.list_applications_filtered(
        scope(session),
        Map.take(params, @listing_fields)
      )

    reply(text(Serializer.application_page(page)), session)
  end

  @doc "Returns one application owned by the caller."
  def applications_get(%{"id" => id}, session) do
    with_application(session, id, fn application ->
      reply(text(%{"application" => Serializer.application(application)}), session)
    end)
  end

  @doc "Creates an application owned by the caller."
  def applications_create(params, session) do
    attrs = Map.take(params, @application_fields)

    case JobApplications.create_application_with_tags(
           scope(session),
           attrs,
           tag_ids(params),
           new_tag_names(params)
         ) do
      {:ok, application} ->
        reply(text(%{"application" => serialize_application(session, application.id)}), session)

      {:error, changeset} ->
        validation_error(session, changeset)
    end
  end

  @doc "Updates an application owned by the caller."
  def applications_update(%{"id" => id} = params, session) do
    with_application(session, id, fn application ->
      attrs = Map.take(params, @application_fields)
      tag_ids = replacement_tag_ids(params, application.tags)

      case JobApplications.update_application_with_tags(
             scope(session),
             application,
             attrs,
             tag_ids,
             new_tag_names(params)
           ) do
        {:ok, updated} ->
          reply(text(%{"application" => serialize_application(session, updated.id)}), session)

        {:error, changeset} ->
          validation_error(session, changeset)
      end
    end)
  end

  @doc "Hard-deletes an application owned by the caller."
  def applications_delete(%{"id" => id}, session) do
    with_application(session, id, fn application ->
      case JobApplications.delete_application(scope(session), application) do
        {:ok, deleted} ->
          reply(text(%{"deleted" => true, "id" => deleted.id}), session)

        {:error, changeset} ->
          validation_error(session, changeset)
      end
    end)
  end

  @doc "Changes an application's status and appends a history record."
  def applications_change_status(%{"id" => id, "status" => slug} = params, session) do
    with_application(session, id, fn _application ->
      do_change_status(session, id, slug, params)
    end)
  end

  defp do_change_status(session, id, slug, params) do
    case JobApplications.get_status_by_slug(slug) do
      nil ->
        reply(unknown_status(slug), session)

      status ->
        attrs = %{"status_id" => status.id, "notes" => Map.get(params, "notes")}

        case JobApplications.change_status(scope(session), id, attrs) do
          {:ok, updated} ->
            reply(text(%{"application" => serialize_application(session, updated.id)}), session)

          {:error, changeset} ->
            validation_error(session, changeset)
        end
    end
  end

  @doc "Lists the status history of an application owned by the caller."
  def applications_status_history(%{"id" => id}, session) do
    with_application(session, id, fn _application ->
      history =
        JobApplications.list_status_history(scope(session), id)
        |> Enum.map(&Serializer.history/1)

      reply(text(%{"history" => history}), session)
    end)
  end

  ## Resumes

  @doc "Lists the caller's resumes, most recently updated first."
  def resumes_list(_params, session) do
    resumes =
      Resumes.list_resumes(scope(session))
      |> Enum.map(&Serializer.resume/1)

    reply(text(%{"resumes" => resumes}), session)
  end

  @doc "Returns one resume owned by the caller."
  def resumes_get(%{"id" => id}, session) do
    with_resume(session, id, fn resume ->
      reply(text(%{"resume" => Serializer.resume(resume)}), session)
    end)
  end

  @doc "Creates a resume owned by the caller."
  def resumes_create(params, session) do
    attrs = Map.take(params, @resume_fields)

    case Resumes.create_resume_with_tags(
           scope(session),
           attrs,
           tag_ids(params),
           new_tag_names(params)
         ) do
      {:ok, resume} ->
        reply(text(%{"resume" => serialize_resume(session, resume.id)}), session)

      {:error, changeset} ->
        validation_error(session, changeset)
    end
  end

  @doc "Updates a resume owned by the caller."
  def resumes_update(%{"id" => id} = params, session) do
    with_resume(session, id, fn resume ->
      attrs = Map.take(params, @resume_fields)
      tag_ids = replacement_tag_ids(params, resume.tags)

      case Resumes.update_resume_with_tags(
             scope(session),
             resume,
             attrs,
             tag_ids,
             new_tag_names(params)
           ) do
        {:ok, updated} ->
          reply(text(%{"resume" => serialize_resume(session, updated.id)}), session)

        {:error, changeset} ->
          validation_error(session, changeset)
      end
    end)
  end

  @doc "Hard-deletes a resume owned by the caller."
  def resumes_delete(%{"id" => id}, session) do
    with_resume(session, id, fn resume ->
      case Resumes.delete_resume(scope(session), resume) do
        {:ok, deleted} ->
          reply(text(%{"deleted" => true, "id" => deleted.id}), session)

        {:error, changeset} ->
          validation_error(session, changeset)
      end
    end)
  end

  ## Reference data

  @doc "Returns the authenticated account's identity."
  def account_get(_params, session) do
    scope = scope(session)

    reply(
      text(%{"id" => scope.user.id, "email" => scope.user.email}),
      session
    )
  end

  @doc "Lists the caller's tags, ordered by name."
  def tags_list(_params, session) do
    tags = Tags.list_tags(scope(session)) |> Enum.map(&Serializer.tag/1)
    reply(text(%{"tags" => tags}), session)
  end

  @doc "Lists the predefined application statuses."
  def statuses_list(_params, session) do
    statuses = JobApplications.list_statuses() |> Enum.map(&Serializer.status/1)
    reply(text(%{"statuses" => statuses}), session)
  end

  ## Helpers

  defp reply(payload, session), do: {:reply, payload, session}

  defp scope(%{assigns: %{scope: %Scope{} = scope}}), do: scope

  defp with_application(session, id, fun) do
    case JobApplications.get_application(scope(session), id) do
      nil -> reply(error("Application #{id} not found."), session)
      application -> fun.(application)
    end
  end

  defp with_resume(session, id, fun) do
    case Resumes.get_resume(scope(session), id) do
      nil -> reply(error("Resume #{id} not found."), session)
      resume -> fun.(resume)
    end
  end

  defp serialize_application(session, id) do
    session |> scope() |> JobApplications.get_application(id) |> Serializer.application()
  end

  defp serialize_resume(session, id) do
    session |> scope() |> Resumes.get_resume(id) |> Serializer.resume()
  end

  defp tag_ids(params), do: params |> Map.get("tag_ids") |> List.wrap()

  defp new_tag_names(params), do: params |> Map.get("new_tag_names") |> List.wrap()

  # A `tag_ids` list replaces the linked tags. When the argument is omitted,
  # the currently linked tags are preserved.
  defp replacement_tag_ids(params, current_tags) do
    case Map.fetch(params, "tag_ids") do
      {:ok, ids} -> List.wrap(ids)
      :error -> Enum.map(current_tags, & &1.id)
    end
  end

  defp unknown_status(slug) do
    valid =
      JobApplications.list_statuses()
      |> Enum.map_join(", ", & &1.slug)

    error("Unknown status #{inspect(slug)}. Valid statuses: #{valid}.")
  end

  defp validation_error(session, changeset) do
    details =
      changeset
      |> Ecto.Changeset.traverse_errors(&interpolate_error/1)
      |> Enum.map_join("; ", fn {field, messages} ->
        "#{field} #{Enum.join(messages, ", ")}"
      end)

    reply(error("Validation failed: #{details}"), session)
  end

  defp interpolate_error({message, opts}) do
    Enum.reduce(opts, message, fn {key, value}, acc ->
      placeholder = "%{#{key}}"

      if String.contains?(acc, placeholder) do
        String.replace(acc, placeholder, to_string(value))
      else
        acc
      end
    end)
  end
end
