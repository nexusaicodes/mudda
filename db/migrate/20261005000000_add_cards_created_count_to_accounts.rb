# Every card an account has ever created, for the optional MUDDA_CARD_LIMIT ceiling (see
# Account::CardLimited). Deleting a card doesn't lower it, so it starts at the cards that
# exist today: the best record there is of what came before.
class AddCardsCreatedCountToAccounts < ActiveRecord::Migration[8.2]
  def up
    add_column :accounts, :cards_created_count, :integer, default: 0, null: false

    execute <<~SQL
      UPDATE accounts SET cards_created_count = (
        SELECT COUNT(*) FROM cards INNER JOIN boards ON boards.id = cards.board_id
        WHERE boards.account_id = accounts.id
      )
    SQL
  end

  def down
    remove_column :accounts, :cards_created_count
  end
end
