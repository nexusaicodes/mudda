require "test_helper"

class Card::NotableTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "capturing notes" do
    assert_difference -> { cards(:logo).notes.count }, +1 do
      cards(:logo).notes.create!(body: "Agreed.")
    end

    assert_equal "Agreed.", cards(:logo).notes.last.body.to_plain_text.chomp
  end

  test "notable? is true for published cards, false for drafts" do
    assert cards(:logo).notable?
    assert_not cards(:unfinished_thoughts).notable?
  end
end
