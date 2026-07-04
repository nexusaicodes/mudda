require "test_helper"

# Covers config/initializers/active_storage_account_scoping.rb: an attached blob must
# belong to the same account as the record it is attached to.
class ActiveStorageAccountScopingTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
    @account = accounts("37s")
    Current.account = @account # Ensure blobs get the right account_id
    @board = @account.boards.create!(name: "Test", creator: users(:david))
  end

  test "allows attaching a blob from the same account" do
    blob = ActiveStorage::Blob.create_and_upload! \
      io: StringIO.new("x" * 1000), filename: "test.png", content_type: "image/png"

    card = @board.cards.create!(title: "Card", creator: users(:david))
    card.image.attach(blob)

    assert card.image.attached?
  end

  test "rejects attaching a blob from a different account" do
    other_account = Account.create!(name: "Other")
    other_board = other_account.boards.create!(name: "Other Board", creator: users(:david))

    # Blob is created in @account's context, so its account_id is @account, not other_account.
    blob = ActiveStorage::Blob.create_and_upload! \
      io: StringIO.new("x" * 1000), filename: "test.png", content_type: "image/png"

    card = other_board.cards.create!(title: "Card", creator: users(:david))
    assert_raises ActiveRecord::RecordNotSaved do
      card.image.attach(blob)
    end
    assert_not card.reload.image.attached?
  end
end
