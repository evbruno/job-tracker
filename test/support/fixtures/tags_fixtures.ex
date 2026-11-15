defmodule TrackMyJobEx.TagsFixtures do
  @moduledoc """
  Test helpers for creating tags.
  """

  alias TrackMyJobEx.Accounts.Scope
  alias TrackMyJobEx.Tags

  def unique_tag_name, do: "Tag #{System.unique_integer([:positive])}"

  def valid_tag_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{name: unique_tag_name()})
  end

  def tag_fixture(%Scope{} = scope, attrs \\ %{}) do
    {:ok, tag} =
      scope
      |> Tags.create_tag(valid_tag_attributes(attrs))

    tag
  end
end
