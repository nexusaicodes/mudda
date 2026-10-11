# Boards have four lanes — Backlog, Todo, Doing, Done — and new cards land in Backlog. Every board
# comes out of this with exactly one Backlog lane and no Triage lane, and no card leaves its board:
#
# 1. A board with Triage but no Backlog renames its Triage lane to Backlog, keeping its cards and spot.
# 2. Cards still in a Triage lane move to that board's Backlog, and the Triage lanes go.
# 3. A board left without a Backlog gets one, leftmost.
class FoldTriageIntoBacklog < ActiveRecord::Migration[8.2]
  def up
    execute <<~SQL
      UPDATE columns SET name = 'Backlog'
      WHERE name = 'Triage'
        AND board_id NOT IN (SELECT board_id FROM columns WHERE name = 'Backlog')
    SQL

    execute <<~SQL
      UPDATE cards SET column_id = (
        SELECT backlog.id FROM columns AS triage
        INNER JOIN columns AS backlog ON backlog.board_id = triage.board_id AND backlog.name = 'Backlog'
        WHERE triage.id = cards.column_id
      )
      WHERE column_id IN (SELECT id FROM columns WHERE name = 'Triage')
    SQL

    execute "DELETE FROM columns WHERE name = 'Triage'"

    execute <<~SQL
      INSERT INTO columns (board_id, name, color, position, created_at, updated_at)
      SELECT boards.id, 'Backlog', 'var(--color-card-2)',
             COALESCE((SELECT MIN(position) FROM columns WHERE columns.board_id = boards.id), 1) - 1,
             CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM boards
      WHERE boards.id NOT IN (SELECT board_id FROM columns WHERE name = 'Backlog')
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
