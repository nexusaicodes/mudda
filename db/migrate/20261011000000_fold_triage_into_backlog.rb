# Boards have four lanes — Backlog, Todo, Doing, Done — and new cards land in Backlog. Cards
# still in a board's Triage lane move to that board's Backlog, and the Triage lanes go.
class FoldTriageIntoBacklog < ActiveRecord::Migration[8.2]
  def up
    execute <<~SQL
      UPDATE cards SET column_id = (
        SELECT backlog.id FROM columns AS triage
        INNER JOIN columns AS backlog ON backlog.board_id = triage.board_id AND backlog.name = 'Backlog'
        WHERE triage.id = cards.column_id
      )
      WHERE column_id IN (SELECT id FROM columns WHERE name = 'Triage')
    SQL

    execute "DELETE FROM columns WHERE name = 'Triage'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
