class ResetBoardsToFixedColumns < ActiveRecord::Migration[8.2]
  # Resets every board to the five fixed lanes (Board::Triageable::DEFAULT_COLUMNS)
  # and places each card in exactly one: closed -> Done, postponed -> Backlog,
  # everything else -> Triage. Then makes column_id mandatory and drops the
  # lifecycle tables. The card mapping runs as set-based SQL so UUIDs are compared
  # in the database; delete_all skips Column callbacks (cards are reassigned below).
  def up
    Board.find_each do |board|
      board.columns.delete_all

      columns = Board::Triageable::DEFAULT_COLUMNS.to_h do |attributes|
        [ attributes[:name], board.columns.create!(attributes) ]
      end

      board.cards.update_all(column_id: columns.fetch("Triage").id)

      if table_exists?(:card_not_nows)
        board.cards.where("id IN (SELECT card_id FROM card_not_nows)")
          .update_all(column_id: columns.fetch("Backlog").id)
      end

      if table_exists?(:closures)
        board.cards.where("id IN (SELECT card_id FROM closures)")
          .update_all(column_id: columns.fetch("Done").id)
      end
    end

    change_column_null :cards, :column_id, false

    drop_table :closures
    drop_table :card_not_nows
    drop_table :card_activity_spikes
    drop_table :entropies
    drop_table :closers_filters
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
