defmodule TrackMyJobEx.JobApplications do
  @moduledoc """
  The JobApplications context.

  All functions that read or write user-owned data take a
  `TrackMyJobEx.Accounts.Scope` as their first argument and scope every query by
  `scope.user.id`. Another user's identifiers behave as "not found".

  Statuses are predefined global data seeded by a migration and are read-only.
  Status transitions and status history creation are implemented in Phase 5;
  this context currently exposes history reads only.
  """

  import Ecto.Query, warn: false

  alias TrackMyJobEx.Accounts.Scope
  alias TrackMyJobEx.JobApplications.ApplicationStatusHistory
  alias TrackMyJobEx.JobApplications.ApplicationTag
  alias TrackMyJobEx.JobApplications.JobApplication
  alias TrackMyJobEx.JobApplications.Status
  alias TrackMyJobEx.Repo
  alias TrackMyJobEx.Tags
  alias TrackMyJobEx.Tags.Tag

  ## Statuses (shared, read-only)

  @doc """
  Lists the predefined statuses in display order.
  """
  def list_statuses do
    Repo.all(from status in Status, order_by: [asc: status.position])
  end

  @doc """
  Gets a predefined status by id.
  """
  def get_status(id) do
    case cast_id(id) do
      {:ok, id} -> Repo.get(Status, id)
      :error -> nil
    end
  end

  @doc """
  Gets a predefined status by its stable slug.
  """
  def get_status_by_slug(slug) when is_binary(slug) do
    Repo.get_by(Status, slug: slug)
  end

  @doc """
  Returns the default status for new applications (`Interested`).
  """
  def default_status do
    case get_status_by_slug("interested") do
      nil -> raise "the Interested status is missing; run the database migrations"
      status -> status
    end
  end

  ## Suggestions

  @doc """
  Lists the distinct company names from the scope's own applications.

  Comparison is case-insensitive while the first entered casing is preserved.
  Results are sorted case-insensitively.
  """
  def list_company_suggestions(%Scope{} = scope) do
    list_suggestions(scope, :company_name)
  end

  @doc """
  Lists the distinct recruiter names from the scope's own applications.

  Comparison is case-insensitive while the first entered casing is preserved.
  Results are sorted case-insensitively.
  """
  def list_recruiter_suggestions(%Scope{} = scope) do
    list_suggestions(scope, :recruiter_name)
  end

  ## Applications

  @doc """
  Lists applications owned by the scope, most recently created first.
  """
  def list_applications(%Scope{} = scope) do
    from(application in JobApplication,
      where: application.user_id == ^scope.user.id,
      order_by: [desc: application.inserted_at, desc: application.id],
      preload: [:status]
    )
    |> Repo.all()
  end

  @doc """
  Gets an application owned by the scope, or `nil`.

  Another user's application id returns `nil`.
  """
  def get_application(%Scope{} = scope, id) do
    case cast_id(id) do
      {:ok, id} ->
        Repo.one(
          from(application in JobApplication,
            where: application.id == ^id and application.user_id == ^scope.user.id,
            preload: [:status, :tags]
          )
        )

      :error ->
        nil
    end
  end

  @doc """
  Gets an application owned by the scope, raising `Ecto.NoResultsError` otherwise.
  """
  def get_application!(%Scope{} = scope, id) do
    case get_application(scope, id) do
      nil -> raise Ecto.NoResultsError, queryable: JobApplication
      application -> application
    end
  end

  @doc """
  Builds a changeset for a new application owned by the scope.

  `user_id` and the default `Interested` status are assigned here and never
  accepted from the caller's attributes.
  """
  def new_application_changeset(%Scope{} = scope, attrs \\ %{}) when is_map(attrs) do
    %JobApplication{user_id: scope.user.id, status_id: default_status().id}
    |> JobApplication.changeset(attrs)
  end

  @doc """
  Creates an application for the scope with the default `Interested` status.

  `user_id` and `status_id` are derived here and never accepted from the
  caller's attributes.
  """
  def create_application(%Scope{} = scope, attrs) when is_map(attrs) do
    scope
    |> new_application_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates an application and links existing and inline-created tags atomically.

  `tag_ids` must belong to the scope. `new_tag_names` are trimmed and reused
  case-insensitively when a matching tag already exists. Any invalid tag rolls
  back the whole operation so no partial application is left behind.
  """
  def create_application_with_tags(%Scope{} = scope, attrs, tag_ids \\ [], new_tag_names \\ []) do
    changeset = new_application_changeset(scope, attrs)

    Repo.transaction(fn ->
      with {:ok, application} <- Repo.insert(changeset),
           {:ok, tags} <- resolve_tags(scope, tag_ids, new_tag_names),
           :ok <- link_tags(application, tags) do
        Repo.preload(application, :tags, force: true)
      else
        {:error, %Ecto.Changeset{} = error} ->
          Repo.rollback({:application_error, error})

        {:error, reason} ->
          Repo.rollback({:tag_error, put_tag_error(changeset, reason)})
      end
    end)
    |> normalize_transaction()
  end

  @doc """
  Builds a changeset for editing an application owned by the scope.
  """
  def change_application(%Scope{} = scope, application_or_id, attrs \\ %{}) do
    scope
    |> fetch_application!(application_or_id)
    |> JobApplication.changeset(attrs)
  end

  @doc """
  Updates an application owned by the scope.

  Accepts a `%JobApplication{}` or an id; either way the record is re-fetched
  through the scope before updating.
  """
  def update_application(%Scope{} = scope, application_or_id, attrs) when is_map(attrs) do
    scope
    |> fetch_application!(application_or_id)
    |> JobApplication.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Hard-deletes an application owned by the scope.

  Status history and tag links are removed by database cascades. Tags are not
  deleted.
  """
  def delete_application(%Scope{} = scope, application_or_id) do
    scope
    |> fetch_application!(application_or_id)
    |> Repo.delete()
  end

  ## Status history (append-only reads)

  @doc """
  Lists the status history for an application owned by the scope, oldest first.
  """
  def list_status_history(%Scope{} = scope, application_or_id) do
    application = fetch_application!(scope, application_or_id)

    from(history in ApplicationStatusHistory,
      where: history.application_id == ^application.id,
      order_by: [asc: history.changed_at, asc: history.id],
      preload: [:previous_status, :new_status]
    )
    |> Repo.all()
  end

  ## Tags

  @doc """
  Lists the tags currently linked to an application owned by the scope.
  """
  def list_application_tags(%Scope{} = scope, application_or_id) do
    application = fetch_application!(scope, application_or_id)

    from(tag in Tag,
      join: application_tag in ApplicationTag,
      on:
        application_tag.tag_id == tag.id and
          application_tag.application_id == ^application.id,
      where: tag.user_id == ^scope.user.id,
      order_by: [asc: tag.name, asc: tag.id]
    )
    |> Repo.all()
  end

  @doc """
  Links a tag to an application owned by the scope and touches the
  application's `updated_at`.

  The tag id is looked up through `TrackMyJobEx.Tags` so a tag owned by another
  user is treated as not found. Both writes happen in one transaction.
  """
  def add_tag_to_application(%Scope{} = scope, application_or_id, tag_or_id) do
    Repo.transaction(fn ->
      application = fetch_application!(scope, application_or_id)
      tag = Tags.get_tag!(scope, association_id(tag_or_id))

      %ApplicationTag{}
      |> ApplicationTag.changeset(%{application_id: application.id, tag_id: tag.id})
      |> Repo.insert()
      |> case do
        {:ok, application_tag} ->
          touch_application(application)
          application_tag

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Unlinks a tag from an application owned by the scope and touches the
  application's `updated_at`.

  Returns `{:ok, :ok}` on success or `{:error, :not_found}` when the link does
  not exist. An application or tag owned by another user is treated as not
  found.
  """
  def remove_tag_from_application(%Scope{} = scope, application_or_id, tag_or_id) do
    Repo.transaction(fn ->
      application = fetch_application!(scope, application_or_id)
      tag = Tags.get_tag!(scope, association_id(tag_or_id))

      from(application_tag in ApplicationTag,
        where:
          application_tag.application_id == ^application.id and
            application_tag.tag_id == ^tag.id
      )
      |> Repo.delete_all()
      |> case do
        {1, _rows} ->
          touch_application(application)
          :ok

        {0, _rows} ->
          Repo.rollback(:not_found)
      end
    end)
  end

  ## Helpers

  defp fetch_application!(%Scope{} = scope, %JobApplication{id: id}) do
    get_application!(scope, id)
  end

  defp fetch_application!(%Scope{} = scope, id) do
    get_application!(scope, id)
  end

  defp association_id(%{id: id}), do: id
  defp association_id(id), do: id

  defp touch_application(application) do
    now = DateTime.utc_now(:second)

    from(a in JobApplication, where: a.id == ^application.id)
    |> Repo.update_all(set: [updated_at: now])

    :ok
  end

  defp resolve_tags(scope, tag_ids, new_tag_names) do
    with {:ok, selected} <- fetch_tags_by_ids(scope, tag_ids),
         {:ok, created} <- get_or_create_tags(scope, new_tag_names) do
      {:ok, Enum.uniq_by(selected ++ created, & &1.id)}
    end
  end

  defp fetch_tags_by_ids(scope, ids) do
    with {:ok, ids} <- cast_ids(List.wrap(ids)) do
      tags =
        from(tag in Tag,
          where: tag.user_id == ^scope.user.id and tag.id in ^ids
        )
        |> Repo.all()

      if length(tags) == length(ids), do: {:ok, tags}, else: {:error, :invalid_tag}
    end
  end

  defp cast_ids(ids) do
    ids
    |> Enum.reduce_while({:ok, []}, fn id, {:ok, acc} ->
      case cast_id(id) do
        {:ok, id} -> {:cont, {:ok, [id | acc]}}
        :error -> {:halt, :error}
      end
    end)
    |> case do
      {:ok, ids} -> {:ok, ids |> Enum.reverse() |> Enum.uniq()}
      :error -> {:error, :invalid_tag}
    end
  end

  defp get_or_create_tags(scope, names) when is_list(names) do
    names =
      names
      |> Enum.filter(&is_binary/1)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq_by(&String.downcase/1)

    Enum.reduce_while(names, {:ok, []}, fn name, {:ok, acc} ->
      case Tags.get_or_create_tag(scope, name) do
        {:ok, tag} -> {:cont, {:ok, [tag | acc]}}
        {:error, _reason} -> {:halt, {:error, :invalid_tag}}
      end
    end)
    |> case do
      {:ok, tags} -> {:ok, Enum.reverse(tags)}
      error -> error
    end
  end

  defp get_or_create_tags(_scope, _names), do: {:error, :invalid_tag}

  defp link_tags(application, tags) do
    rows = Enum.map(tags, &%{application_id: application.id, tag_id: &1.id})
    Repo.insert_all(ApplicationTag, rows)
    :ok
  end

  defp put_tag_error(changeset, _reason) do
    Ecto.Changeset.add_error(changeset, :tags, "contain an invalid or unknown tag")
  end

  defp normalize_transaction({:ok, application}), do: {:ok, application}
  defp normalize_transaction({:error, {:application_error, changeset}}), do: {:error, changeset}
  defp normalize_transaction({:error, {:tag_error, changeset}}), do: {:error, changeset}

  defp list_suggestions(%Scope{} = scope, field) do
    from(application in JobApplication,
      where:
        application.user_id == ^scope.user.id and
          not is_nil(field(application, ^field)),
      select: field(application, ^field)
    )
    |> Repo.all()
    |> Enum.uniq_by(&String.downcase/1)
    |> Enum.sort_by(&{String.downcase(&1), &1})
  end

  defp cast_id(id), do: Ecto.Type.cast(:id, id)
end
