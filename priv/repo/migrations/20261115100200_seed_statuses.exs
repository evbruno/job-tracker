defmodule TrackMyJobEx.Repo.Migrations.SeedStatuses do
  use Ecto.Migration

  @statuses [
    {"interested", "Interested", 1},
    {"applied", "Applied", 2},
    {"screening", "Screening", 3},
    {"interview", "Interview", 4},
    {"technical_interview", "Technical Interview", 5},
    {"final_interview", "Final Interview", 6},
    {"offer", "Offer", 7},
    {"accepted", "Accepted", 8},
    {"declined", "Declined", 9},
    {"rejected", "Rejected", 10},
    {"withdrawn", "Withdrawn", 11},
    {"failed", "Failed", 12},
    {"on_hold", "On Hold", 13}
  ]

  def up do
    values =
      Enum.map_join(@statuses, ",\n", fn {slug, name, position} ->
        "('#{slug}', '#{name}', #{position})"
      end)

    execute("""
    INSERT INTO statuses (slug, name, position) VALUES
    #{values}
    """)
  end

  def down do
    execute("DELETE FROM statuses")
  end
end
