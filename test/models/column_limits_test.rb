require "test_helper"

class ColumnLimitsTest < ActiveSupport::TestCase
  # SQLite enforces the limits with CHECK constraints; see config/initializers/table_definition_column_limits.rb.
  COLUMN_LIMIT_ERRORS = [ ActiveRecord::CheckViolation ]

  test "board name rejects strings over 255 characters" do
    board = Board.new(name: "a" * 256, account: accounts("37s"), creator: users(:david))
    assert_raises(*COLUMN_LIMIT_ERRORS) { board.save! }
  end

  test "board name accepts strings up to 255 characters" do
    board = Board.new(name: "a" * 255, account: accounts("37s"), creator: users(:david))
    assert board.save
  end

  test "board name accepts 255 emoji characters" do
    board = Board.new(name: "🎉" * 255, account: accounts("37s"), creator: users(:david))
    assert board.save
  end

  test "board name rejects 256 emoji characters" do
    board = Board.new(name: "🎉" * 256, account: accounts("37s"), creator: users(:david))
    assert_raises(*COLUMN_LIMIT_ERRORS) { board.save! }
  end

  # Test text column limits (65535 bytes for TEXT)
  test "step content rejects text over 65535 bytes" do
    step = Step.new(content: "a" * 65536, card: cards(:logo))
    assert_raises(*COLUMN_LIMIT_ERRORS) { step.save! }
  end

  test "step content accepts text up to 65535 bytes" do
    step = Step.new(content: "a" * 65535, card: cards(:logo))
    assert step.save
  end

  test "step content counts bytes not characters for text columns" do
    # 20000 emoji = 20000 chars but 80000 bytes (over 65535 limit)
    step = Step.new(content: "🎉" * 20000, card: cards(:logo))
    assert_raises(*COLUMN_LIMIT_ERRORS) { step.save! }
  end

  test "ActionText::RichText name rejects strings over 255 characters" do
    rich_text = ActionText::RichText.new(name: "a" * 256, record: cards(:logo))
    assert_raises(*COLUMN_LIMIT_ERRORS) { rich_text.save! }
  end

  test "ActiveStorage::Blob filename rejects strings over 255 characters" do
    Current.account = accounts(:"37s")
    blob = ActiveStorage::Blob.new(filename: "a" * 256, key: "test-key", byte_size: 0, checksum: "test", service_name: "local")
    assert_raises(*COLUMN_LIMIT_ERRORS) { blob.save! }
  end
end
