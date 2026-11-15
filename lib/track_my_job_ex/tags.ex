defmodule TrackMyJobEx.Tags do
  @moduledoc """
  The Tags context.

  Tags are user-owned. Every function takes a
  `TrackMyJobEx.Accounts.Scope` as its first argument and scopes queries by
  `scope.user.id`; another user's tag id behaves as "not found".

  Name uniqueness is case-insensitive per user, enforced by a `COLLATE NOCASE`
  unique index created in a migration. The original casing is preserved.
  """

  import Ecto.Query, warn: false

  alias TrackMyJobEx.Accounts.Scope
  alias TrackMyJobEx.Repo
  alias TrackMyJobEx.Tags.Tag

  @doc """
  Lists tags owned by the scope, ordered by name.
  """
  def list_tags(%Scope{} = scope) do
    from(tag in Tag,
      where: tag.user_id == ^scope.user.id,
      order_by: [asc: tag.name, asc: tag.id]
    )
    |> Repo.all()
  end

  @doc """
  Gets a tag owned by the scope, or `nil`.

  Another user's tag id returns `nil`.
  """
  def get_tag(%Scope{} = scope, id) do
    case cast_id(id) do
      {:ok, id} ->
        Repo.one(
          from(tag in Tag,
            where: tag.id == ^id and tag.user_id == ^scope.user.id
          )
        )

      :error ->
        nil
    end
  end

  @doc """
  Gets a tag owned by the scope, raising `Ecto.NoResultsError` otherwise.
  """
  def get_tag!(%Scope{} = scope, id) do
    case get_tag(scope, id) do
      nil -> raise Ecto.NoResultsError, queryable: Tag
      tag -> tag
    end
  end

  @doc """
  Creates a tag for the scope.

  `user_id` is derived here and never accepted from the caller's attributes.
  """
  def create_tag(%Scope{} = scope, attrs) when is_map(attrs) do
    %Tag{user_id: scope.user.id}
    |> Tag.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Renames or updates a tag owned by the scope.

  Accepts a `%Tag{}` or an id; either way the record is re-fetched through the
  scope before updating.
  """
  def update_tag(%Scope{} = scope, tag_or_id, attrs) when is_map(attrs) do
    scope
    |> fetch_tag!(tag_or_id)
    |> Tag.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Hard-deletes a tag owned by the scope.

  Tag links are removed by a database cascade. Applications are unaffected.
  """
  def delete_tag(%Scope{} = scope, tag_or_id) do
    scope
    |> fetch_tag!(tag_or_id)
    |> Repo.delete()
  end

  ## Helpers

  defp fetch_tag!(%Scope{} = scope, %Tag{id: id}), do: get_tag!(scope, id)
  defp fetch_tag!(%Scope{} = scope, id), do: get_tag!(scope, id)

  defp cast_id(id), do: Ecto.Type.cast(:id, id)
end
