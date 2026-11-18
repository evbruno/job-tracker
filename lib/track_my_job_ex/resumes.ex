defmodule TrackMyJobEx.Resumes do
  @moduledoc """
  The Resumes context.

  All functions that read or write user-owned data take a
  `TrackMyJobEx.Accounts.Scope` as their first argument and scope every query by
  `scope.user.id`. Another user's identifiers behave as "not found".

  Each user can keep many independent resume versions. The create changeset
  prefills the email from the scope's user; the field stays editable afterwards.
  Tags are the same user-owned tags used by job applications and are linked
  through `resume_tags`.
  """

  import Ecto.Query, warn: false

  alias TrackMyJobEx.Accounts.Scope
  alias TrackMyJobEx.Repo
  alias TrackMyJobEx.Resumes.Resume
  alias TrackMyJobEx.Resumes.ResumeTag
  alias TrackMyJobEx.Tags
  alias TrackMyJobEx.Tags.Tag

  ## Resumes

  @doc """
  Lists resumes owned by the scope, most recently updated first.
  """
  def list_resumes(%Scope{} = scope) do
    from(resume in Resume,
      where: resume.user_id == ^scope.user.id,
      order_by: [desc: resume.updated_at, desc: resume.id],
      preload: [:tags]
    )
    |> Repo.all()
  end

  @doc """
  Gets a resume owned by the scope, or `nil`.

  Another user's resume id returns `nil`.
  """
  def get_resume(%Scope{} = scope, id) do
    case cast_id(id) do
      {:ok, id} ->
        Repo.one(
          from(resume in Resume,
            where: resume.id == ^id and resume.user_id == ^scope.user.id,
            preload: [:tags]
          )
        )

      :error ->
        nil
    end
  end

  @doc """
  Gets a resume owned by the scope, raising `Ecto.NoResultsError` otherwise.
  """
  def get_resume!(%Scope{} = scope, id) do
    case get_resume(scope, id) do
      nil -> raise Ecto.NoResultsError, queryable: Resume
      resume -> resume
    end
  end

  @doc """
  Builds a changeset for a new resume owned by the scope.

  `user_id` is assigned here and never accepted from the caller's attributes.
  The email defaults to the signed-in user's email; a caller-supplied email
  overrides the default and an explicit blank value fails validation.
  """
  def new_resume_changeset(%Scope{} = scope, attrs \\ %{}) when is_map(attrs) do
    %Resume{user_id: scope.user.id, email: scope.user.email}
    |> Resume.changeset(attrs)
  end

  @doc """
  Creates a resume owned by the scope.

  The email is prefilled from the scope's user when the caller does not supply
  one.
  """
  def create_resume(%Scope{} = scope, attrs) when is_map(attrs) do
    scope
    |> new_resume_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a resume and links existing and inline-created tags atomically.

  `tag_ids` must belong to the scope. `new_tag_names` are trimmed and reused
  case-insensitively when a matching tag already exists. Any invalid tag rolls
  back the resume so no partial record is left behind.
  """
  def create_resume_with_tags(%Scope{} = scope, attrs, tag_ids \\ [], new_tag_names \\ []) do
    changeset = new_resume_changeset(scope, attrs)

    Ecto.Multi.new()
    |> Ecto.Multi.insert(:resume, changeset)
    |> Ecto.Multi.run(:tags, fn _repo, %{resume: resume} ->
      with {:ok, tags} <- resolve_tags(scope, tag_ids, new_tag_names),
           :ok <- link_tags(resume, tags) do
        {:ok, tags}
      end
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{resume: resume}} ->
        {:ok, Repo.preload(resume, :tags, force: true)}

      {:error, :resume, error, _changes} ->
        {:error, error}

      {:error, :tags, reason, _changes} ->
        {:error, put_tag_error(changeset, reason)}

      {:error, _step, error, _changes} ->
        {:error, error}
    end
  end

  @doc """
  Builds a changeset for editing a resume owned by the scope.
  """
  def change_resume(%Scope{} = scope, resume_or_id, attrs \\ %{}) do
    scope
    |> fetch_resume!(resume_or_id)
    |> Resume.changeset(attrs)
  end

  @doc """
  Updates a resume owned by the scope.

  Accepts a `%Resume{}` or an id; either way the record is re-fetched through
  the scope before updating.
  """
  def update_resume(%Scope{} = scope, resume_or_id, attrs) when is_map(attrs) do
    scope
    |> fetch_resume!(resume_or_id)
    |> Resume.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates a resume and replaces its tag links atomically.

  Selected `tag_ids` must belong to the scope and inline `new_tag_names` are
  reused case-insensitively. Any invalid tag rolls back both the field updates
  and the tag links. Tag changes touch the resume's `updated_at`.
  """
  def update_resume_with_tags(
        %Scope{} = scope,
        resume_or_id,
        attrs,
        tag_ids \\ [],
        new_tag_names \\ []
      ) do
    resume = fetch_resume!(scope, resume_or_id)
    changeset = Resume.changeset(resume, attrs)

    Repo.transaction(fn ->
      with {:ok, resume} <- Repo.update(changeset),
           {:ok, tags} <- resolve_tags(scope, tag_ids, new_tag_names),
           :ok <- sync_tag_links(resume, tags) do
        Repo.preload(resume, :tags, force: true)
      else
        {:error, %Ecto.Changeset{} = error} ->
          Repo.rollback({:resume_error, error})

        {:error, reason} ->
          Repo.rollback({:tag_error, put_tag_error(changeset, reason)})
      end
    end)
    |> normalize_transaction()
  end

  @doc """
  Replaces the tags linked to a resume owned by the scope.

  Returns `{:ok, resume}` with the tags preloaded, or an error changeset when
  any tag is unknown or belongs to another user.
  """
  def set_resume_tags(%Scope{} = scope, resume_or_id, tag_ids) do
    update_resume_with_tags(scope, resume_or_id, %{}, tag_ids, [])
  end

  @doc """
  Hard-deletes a resume owned by the scope.

  Tag links are removed by a database cascade. Tags are not deleted.
  """
  def delete_resume(%Scope{} = scope, resume_or_id) do
    scope
    |> fetch_resume!(resume_or_id)
    |> Repo.delete()
  end

  ## Tags

  @doc """
  Lists the tags currently linked to a resume owned by the scope.
  """
  def list_resume_tags(%Scope{} = scope, resume_or_id) do
    resume = fetch_resume!(scope, resume_or_id)

    from(tag in Tag,
      join: resume_tag in ResumeTag,
      on: resume_tag.tag_id == tag.id and resume_tag.resume_id == ^resume.id,
      where: tag.user_id == ^scope.user.id,
      order_by: [asc: tag.name, asc: tag.id]
    )
    |> Repo.all()
  end

  ## Helpers

  defp fetch_resume!(%Scope{} = scope, %Resume{id: id}), do: get_resume!(scope, id)
  defp fetch_resume!(%Scope{} = scope, id), do: get_resume!(scope, id)

  defp touch_resume(resume) do
    now = DateTime.utc_now(:second)

    from(r in Resume, where: r.id == ^resume.id)
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

  defp sync_tag_links(resume, tags) do
    current_ids = linked_tag_ids(resume)
    desired_ids = tags |> Enum.map(& &1.id) |> Enum.uniq()
    to_add = desired_ids -- current_ids
    to_remove = current_ids -- desired_ids

    if to_add != [] or to_remove != [] do
      delete_tag_links(resume, to_remove)
      insert_tag_links(resume, to_add)
      touch_resume(resume)
    end

    :ok
  end

  defp linked_tag_ids(resume) do
    from(resume_tag in ResumeTag,
      where: resume_tag.resume_id == ^resume.id,
      select: resume_tag.tag_id
    )
    |> Repo.all()
  end

  defp delete_tag_links(_resume, []), do: :ok

  defp delete_tag_links(resume, tag_ids) do
    from(resume_tag in ResumeTag,
      where: resume_tag.resume_id == ^resume.id and resume_tag.tag_id in ^tag_ids
    )
    |> Repo.delete_all()

    :ok
  end

  defp insert_tag_links(_resume, []), do: :ok

  defp insert_tag_links(resume, tag_ids) do
    rows = Enum.map(tag_ids, &%{resume_id: resume.id, tag_id: &1})
    Repo.insert_all(ResumeTag, rows)
    :ok
  end

  defp link_tags(resume, tags) do
    rows = Enum.map(tags, &%{resume_id: resume.id, tag_id: &1.id})
    Repo.insert_all(ResumeTag, rows)
    :ok
  end

  defp put_tag_error(changeset, _reason) do
    Ecto.Changeset.add_error(changeset, :tags, "contain an invalid or unknown tag")
  end

  defp normalize_transaction({:ok, resume}), do: {:ok, resume}
  defp normalize_transaction({:error, {:resume_error, changeset}}), do: {:error, changeset}
  defp normalize_transaction({:error, {:tag_error, changeset}}), do: {:error, changeset}

  defp cast_id(id), do: Ecto.Type.cast(:id, id)
end
