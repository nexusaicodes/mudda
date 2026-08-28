require "test_helper"

class Card::NotableTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "a new card has no notes" do
    card = boards(:writebook).cards.create! creator: users(:kevin), title: "New", due_on: 1.week.from_now

    assert_empty card.notes
  end

  test "capturing notes" do
    assert_difference -> { cards(:logo).notes.count }, +1 do
      cards(:logo).notes.create!(body: "Agreed.")
    end

    assert_equal "Agreed.", cards(:logo).notes.last.body.to_plain_text.chomp
  end
end
