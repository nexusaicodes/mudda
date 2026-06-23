require "test_helper"

class FilterTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "cards" do
    @new_board = Board.create! name: "Inaccessible Board", creator: users(:david)
    @new_card = @new_board.cards.create!(status: "published")

    cards(:layout).comments.create!(body: "I hate haggis")
    cards(:logo).comments.create!(body: "I love haggis")

    assert_not_includes users(:kevin).filters.new.cards, @new_card

    filter = users(:david).filters.new assignment_status: "unassigned", board_ids: [ @new_board.id ]
    assert_equal [ @new_card ], filter.cards

    filter = users(:david).filters.new column_ids: [ columns(:writebook_doing).id ]
    assert_equal [ cards(:text) ], filter.cards

    filter = users(:david).filters.new card_ids: [ cards(:logo, :layout).collect(&:id) ]
    assert_equal [ cards(:logo), cards(:layout) ], filter.cards
  end

  test "can't see cards in boards that aren't accessible" do
    boards(:writebook).update! all_access: false
    boards(:writebook).accesses.revoke_from users(:david)

    assert_empty users(:david).filters.new(board_ids: [ boards(:writebook).id ]).cards
  end

  test "can't see boards that aren't accessible" do
    boards(:writebook).update! all_access: false
    boards(:writebook).accesses.revoke_from users(:david)

    assert_empty users(:david).filters.new(board_ids: [ boards(:writebook).id ]).boards
  end

  test "remembering equivalent filters" do
    assert_difference "Filter.count", +1 do
      filter = users(:david).filters.remember(sorted_by: "latest", assignment_status: "unassigned", assignee_ids: [ users(:jz).id ])

      assert_changes "filter.reload.updated_at" do
        assert_equal filter, users(:david).filters.remember(assignee_ids: [ users(:jz).id ], assignment_status: "unassigned")
      end
    end
  end

  test "remembering equivalent filters for different users" do
    assert_difference "Filter.count", +2 do
      users(:david).filters.remember(assignment_status: "unassigned", assignee_ids: [ users(:jz).id ])
      users(:kevin).filters.remember(assignment_status: "unassigned", assignee_ids: [ users(:jz).id ])
    end
  end

  test "turning into params" do
    filter = users(:david).filters.new sorted_by: "latest", assignee_ids: [ users(:jz).id ], board_ids: [ boards(:writebook).id ]
    expected = { assignee_ids: [ users(:jz).id ], board_ids: [ boards(:writebook).id ] }
    assert_equal expected, filter.as_params
  end

  test "cacheability" do
    assert_not filters(:jz_assignments).cacheable?
    assert users(:david).filters.create!(board_ids: [ boards(:writebook).id ]).cacheable?
  end

  test "terms" do
    assert_equal [], users(:david).filters.new.terms
    assert_equal [ "haggis" ], users(:david).filters.new(terms: [ "haggis" ]).terms
  end

  test "resource removal" do
    other_board = Board.create!(name: "Another board", creator: users(:david))
    filter = users(:david).filters.create! board_ids: [ boards(:writebook).id, other_board.id ]

    assert_includes filter.as_params[:board_ids], boards(:writebook).id
    assert_includes filter.boards, boards(:writebook)

    assert_changes "filter.reload.updated_at" do
      boards(:writebook).destroy!
    end
    assert_not_includes Filter.find(filter.id).as_params[:board_ids], boards(:writebook).id

    assert_changes "Filter.exists?(filter.id)" do
      other_board.destroy!
    end
  end

  test "duplicate filters are removed after a resource is destroyed" do
    other_board = Board.create!(name: "Another board", creator: users(:david))
    users(:david).filters.create! board_ids: [ other_board.id ]
    users(:david).filters.create! board_ids: [ other_board.id, boards(:writebook).id ]

    assert_difference "Filter.count", -1 do
      boards(:writebook).destroy!
    end
  end

  test "summary" do
    assert_equal "Newest and assigned to JZ", filters(:jz_assignments).summary

    filters(:jz_assignments).update!(assignees: [], boards: [ boards(:writebook) ])
    assert_equal "Newest", filters(:jz_assignments).summary
  end

  test "get a clone with some changed params" do
    seed_filter = users(:david).filters.new indexed_by: "all", terms: [ "haggis" ]
    filter = seed_filter.with(indexed_by: "golden")

    assert filter.indexed_by.golden?
    assert_equal [ "haggis" ], filter.terms
  end

  test "creation window" do
    filter = users(:david).filters.new creation: "this week"

    cards(:logo).update_columns created_at: 2.weeks.ago
    assert_not_includes filter.cards, cards(:logo)

    cards(:logo).update_columns created_at: Time.current
    assert_includes filter.cards, cards(:logo)
  end

  test "check if a filter is used" do
    assert users(:david).filters.new(creator_ids: [ users(:david).id ]).used?
    assert_not users(:david).filters.new.used?

    assert users(:david).filters.new(board_ids: [ boards(:writebook).id ]).used?
    assert_not users(:david).filters.new(board_ids: [ boards(:writebook).id ]).used?(ignore_boards: true)
  end

  test "column ids filter cards by workflow columns" do
    assert_equal [ cards(:text) ], users(:david).filters.new(column_ids: [ columns(:writebook_doing).id ]).cards.to_a
    assert_equal [ cards(:logo), cards(:layout), cards(:buy_domain) ].sort_by(&:id), users(:david).filters.new(column_ids: [ columns(:writebook_triage).id ]).cards.to_a.sort_by(&:id)
  end

  test "column ids are ORed together" do
    filter = users(:david).filters.new(column_ids: [ columns(:writebook_triage).id, columns(:writebook_doing).id ])

    assert_equal [ cards(:logo), cards(:layout), cards(:buy_domain), cards(:text) ].sort_by(&:id), filter.cards.to_a.sort_by(&:id)
  end

  test "board titles are scoped to creator's account" do
    # Give mike (initech) access to the board in his account
    boards(:miltons_wish_list).accesses.grant_to(users(:mike))
    assert_equal 1, users(:mike).boards.count

    # Filter with no boards selected should show the single board name from mike's account
    filter = users(:mike).filters.new(creator: users(:mike))
    assert_equal [ "Milton's Wish List" ], filter.board_titles

    # Should NOT leak board names from other accounts (37s has multiple boards)
    assert Board.where.not(account: accounts(:initech)).exists?
    assert_not_includes filter.board_titles, "Writebook"
    assert_not_includes filter.board_titles, "Private board"
  end
end
