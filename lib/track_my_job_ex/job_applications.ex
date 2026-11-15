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

  ## Applications

  @doc """
  Lists applications owned by the scope, most recently created first.
  """
  def list_applications(%Scope{} = scope) do
    from(application in JobApplication,
      where: application.user_id == ^scope.user.id,
      order_by: [desc: application.inserted_at, desc: application.id]
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
  Creates an application for the scope with the default `Interested` status.

  `user_id` and `status_id` are derived here and never accepted from the
  caller's attributes.
  """
  def create_application(%Scope{} = scope, attrs) when is_map(attrs) do
    %JobApplication{user_id: scope.user.id, status_id: default_status().id}
    |> JobApplication.changeset(attrs)
    |> Repo.insert()
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

  defp cast_id(id), do: Ecto.Type.cast(:id, id)
end
