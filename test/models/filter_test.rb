require "test_helper"

class FilterTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "cards" do
    @new_board = Board.create! name: "Another Board", creator: users(:david)
    @new_card = @new_board.cards.create!(due_on: 1.week.from_now)

    cards(:layout).notes.create!(body: "I hate haggis")
    cards(:logo).notes.create!(body: "I love haggis")

    filter = Filter.new users(:david), board_ids: [ @new_board.id ]
    assert_equal [ @new_card ], filter.cards

    filter = Filter.new users(:david), column_ids: [ columns(:writebook_doing).id ]
    assert_equal [ cards(:text) ], filter.cards

    filter = Filter.new users(:david), card_ids: [ cards(:logo, :layout).collect(&:id) ]
    assert_equal [ cards(:logo), cards(:layout) ], filter.cards
  end

  test "turning into params" do
    filter = Filter.new users(:david), sorted_by: "newest", board_ids: [ boards(:writebook).id ]
    expected = { sorted_by: "newest", board_ids: [ boards(:writebook).id ] }
    assert_equal expected, filter.as_params
  end

  test "terms" do
    assert_equal [], Filter.new(users(:david)).terms
    assert_equal [ "haggis" ], Filter.new(users(:david), terms: [ "haggis" ]).terms
  end

  test "creation window" do
    filter = Filter.new users(:david), creation: "this week"

    cards(:logo).update_columns created_at: 2.weeks.ago
    assert_not_includes filter.cards, cards(:logo)

    cards(:logo).update_columns created_at: Time.current
    assert_includes filter.cards, cards(:logo)
  end

  test "column ids filter cards by workflow columns" do
    assert_equal [ cards(:text) ], Filter.new(users(:david), column_ids: [ columns(:writebook_doing).id ]).cards.to_a
    assert_equal [ cards(:logo), cards(:layout), cards(:buy_domain) ].sort_by(&:id), Filter.new(users(:david), column_ids: [ columns(:writebook_backlog).id ]).cards.to_a.sort_by(&:id)
  end

  test "column ids are ORed together" do
    filter = Filter.new(users(:david), column_ids: [ columns(:writebook_backlog).id, columns(:writebook_doing).id ])

    assert_equal [ cards(:logo), cards(:layout), cards(:buy_domain), cards(:text) ].sort_by(&:id), filter.cards.to_a.sort_by(&:id)
  end

  test "board titles are scoped to creator's account" do
    # Mike (initech) sees the single board in his account
    assert_equal 1, users(:mike).boards.count

    # Filter with no boards selected should show the single board name from mike's account
    filter = Filter.new(users(:mike))
    assert_equal "Milton's Wish List", filter.boards_label

    # Should NOT leak board names from other accounts (37s has multiple boards)
    assert Board.where.not(account: accounts(:initech)).exists?
    assert_no_match(/Writebook|Private board/, filter.boards_label)
  end

  test "due soon holds open cards due by tomorrow, the most overdue first" do
    board = boards(:writebook)
    overdue  = board.cards.create!(title: "Overdue", due_on: 3.days.ago)
    today    = board.cards.create!(title: "Today", due_on: Date.current)
    tomorrow = board.cards.create!(title: "Tomorrow", due_on: Date.tomorrow)
    later    = board.cards.create!(title: "Later", due_on: 3.days.from_now)
    finished = board.cards.create!(title: "Finished", due_on: Date.yesterday)
    finished.update!(column: columns(:writebook_done))

    cards = Filter.new(users(:david), due: "soon").cards.to_a

    assert_equal [ overdue, today, tomorrow ], cards & [ overdue, today, tomorrow ]
    assert_operator cards.index(overdue), :<, cards.index(today)
    assert_not_includes cards, later
    assert_not_includes cards, finished
  end

  test "lane narrows to a lane by name on every board" do
    cards = Filter.new(users(:david), lane: "doing").cards

    assert cards.any?
    assert cards.all? { |card| card.column.name == "Doing" }
    assert Filter.new(users(:david), lane: "DOING").cards.all? { |card| card.column.name == "Doing" }
  end

  test "values outside their lists make the filter invalid" do
    assert Filter.new(users(:david), due: "soon", lane: "doing", creation: "this week").valid?

    filter = Filter.new(users(:david), due: "today", lane: "nowhere", indexed_by: "shiny", sorted_by: "random", creation: "someday")
    assert_not filter.valid?
    assert_equal %i[ creation due indexed_by lane sorted_by ], filter.errors.attribute_names.sort
  end

  test "a view's filter knows its name" do
    assert_equal "Due today & tomorrow", Filter.new(users(:david), due: "soon").view_name
    assert_equal "Golden", Filter.new(users(:david), indexed_by: "golden").view_name
    assert_nil Filter.new(users(:david), due: "soon", indexed_by: "golden").view_name
  end
end
