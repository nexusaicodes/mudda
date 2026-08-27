require "test_helper"

class CardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "index" do
    get cards_path
    assert_response :success
  end

  test "filtered index" do
    get cards_path(filters(:newest_first).as_params.merge(term: "haggis"))
    assert_response :success
  end

  test "index as JSON can filter by workflow column id" do
    get cards_path(format: :json), params: { column_ids: [ columns(:writebook_doing).id ] }
    assert_response :success

    assert_equal [ cards(:text).number ], @response.parsed_body["data"].pluck("number")
  end

  test "index as JSON can OR multiple workflow column ids" do
    get cards_path(format: :json), params: { column_ids: [ columns(:writebook_triage).id, columns(:writebook_doing).id ] }
    assert_response :success

    assert_equal [ cards(:logo).number, cards(:layout).number, cards(:buy_domain).number, cards(:text).number ].sort, @response.parsed_body["data"].pluck("number").sort
  end

  # Opening the compose screen must not reach the database: a card that is never submitted
  # would otherwise take a number with it.
  test "new" do
    board = boards(:writebook)

    assert_no_difference [ -> { Card.count }, -> { board.reload.cards_count } ] do
      get new_board_card_path(board)
    end

    assert_response :success
    assert_select "form#card_form"
  end

  test "create builds the whole card from the form" do
    board = boards(:writebook)

    assert_difference -> { Card.count }, 1 do
      post board_cards_path(board), params: { card: {
        title: "One shot", due_on: 1.week.from_now.to_date,
        steps_attributes: [ { content: "First" }, { content: "Second" } ] } }
    end

    card = Card.last
    assert_redirected_to board_card_path(board, card)
    assert_equal "One shot", card.title
    assert_equal [ "First", "Second" ], card.steps.map(&:content).sort
    assert_equal "Triage", card.column.name
  end

  # A blank step row is the form offering one, so it must not fail the card.
  test "create ignores blank step rows" do
    assert_difference -> { Card.count }, 1 do
      post board_cards_path(boards(:writebook)), params: { card: {
        title: "Sparse", due_on: 1.week.from_now.to_date,
        steps_attributes: [ { content: "Only one" }, { content: "" } ] } }
    end

    assert_equal [ "Only one" ], Card.last.steps.map(&:content)
  end

  test "create renders the form again when the card is invalid" do
    assert_no_difference -> { Card.count } do
      post board_cards_path(boards(:writebook)), params: { card: { title: "No due date" } }
    end

    assert_response :unprocessable_entity
    assert_select "form#card_form"
  end

  test "show renders inline code in title" do
    card = cards(:logo)
    card.update_column :title, "Fix the `bug` in production"

    get board_card_path(card.board, card)
    assert_select ".card__title-link" do |element|
      assert_equal "Fix the <code>bug</code> in production", element.inner_html
    end
  end

  test "edit" do
    get edit_board_card_path(cards(:logo).board, cards(:logo))
    assert_response :success
  end

  test "edit card with invalid attachments in description" do
    card = cards(:logo)
    card.update! description: <<~HTML
      <action-text-attachment sgid="gid://mudda/Card/nonexistent" content-type="application/octet-stream"></action-text-attachment>
    HTML

    get edit_board_card_path(card.board, card)
    assert_response :success
  end

  test "update" do
    patch board_card_path(cards(:logo).board, cards(:logo)), as: :turbo_stream, params: {
      card: {
        title: "Logo needs to change",
        description: "Something more in-depth" } }
    assert_response :success

    card = cards(:logo).reload
    assert_equal "Logo needs to change", card.title
    assert_equal "Something more in-depth", card.description.to_plain_text.strip
  end

  test "edit form renders a due date field" do
    get edit_board_card_path(cards(:logo).board, cards(:logo))
    assert_response :success
    assert_select "input[type=date][name=?]", "card[due_on]"
  end

  test "update changes the due date" do
    patch board_card_path(cards(:logo).board, cards(:logo)), as: :turbo_stream, params: {
      card: { due_on: "2030-01-15" } }
    assert_response :success

    assert_equal Date.new(2030, 1, 15), cards(:logo).reload.due_on
  end

  test "delete card" do
    assert_difference -> { Card.count }, -1 do
      delete board_card_path(cards(:logo).board, cards(:logo))
    end

    assert_redirected_to boards(:writebook)
  end

  test "show card with note containing malformed remote image attachment" do
    card = cards(:logo)
    card.notes.create! \
      creator: users(:kevin),
      body: '<action-text-attachment url="image.png" content-type="image/*" presentation="gallery"></action-text-attachment>'

    get board_card_path(card.board, card)
    assert_response :success
  end

  test "show as JSON" do
    card = cards(:logo)
    card.steps.create!(content: "First step")
    card.steps.create!(content: "Second step", completed: true)

    get board_card_path(card.board, card), as: :json
    assert_response :success

    assert_equal card.title, @response.parsed_body["title"]
    assert_equal card.closed?, @response.parsed_body["closed"]
    assert_equal card.postponed?, @response.parsed_body["postponed"]
    assert_equal 2, @response.parsed_body["steps"].size
  end

  test "create as JSON" do
    assert_difference -> { Card.count }, +1 do
      post board_cards_path(boards(:writebook)),
        params: { card: { title: "My new card", description: "Big if true", due_on: 1.week.from_now } },
        as: :json
      assert_response :created
    end

    card = Card.last
    assert_equal board_card_path(card.board, card, format: :json), @response.headers["Location"]
    assert_equal "My new card", @response.parsed_body["title"]

    assert_equal "My new card", card.title
    assert_equal "Big if true", card.description.to_plain_text
  end

  test "create as JSON without a due date is rejected" do
    assert_no_difference -> { Card.count } do
      post board_cards_path(boards(:writebook)),
        params: { card: { title: "No due date" } },
        as: :json
      assert_response :unprocessable_entity
    end

    assert_includes @response.parsed_body["errors"].keys, "due_on"
  end

  test "update as JSON cannot blank out a card's due date" do
    card = cards(:logo)

    put board_card_path(card.board, card, format: :json), params: { card: { due_on: "" } }
    assert_response :unprocessable_entity

    assert_predicate card.reload.due_on, :present?
  end

  test "create as JSON with custom created_at" do
    custom_time = Time.utc(2024, 1, 15, 10, 30, 0)

    assert_difference -> { Card.count }, +1 do
      post board_cards_path(boards(:writebook)),
        params: { card: { title: "Backdated card", created_at: custom_time, due_on: 1.week.from_now } },
        as: :json
      assert_response :created
    end

    assert_equal custom_time, Card.last.created_at
  end

  test "create as JSON with custom last_active_at" do
    created_time = Time.utc(2024, 1, 15, 10, 30, 0)
    last_active_time = Time.utc(2024, 6, 1, 12, 0, 0)

    assert_difference -> { Card.count }, +1 do
      post board_cards_path(boards(:writebook)),
        params: { card: { title: "Card with activity", created_at: created_time, last_active_at: last_active_time, due_on: 1.week.from_now } },
        as: :json
      assert_response :created
    end

    card = Card.last
    assert_equal created_time, card.created_at
    assert_equal last_active_time, card.last_active_at
  end

  test "create as JSON defaults last_active_at to created_at when not provided" do
    created_time = Time.utc(2024, 1, 15, 10, 30, 0)

    assert_difference -> { Card.count }, +1 do
      post board_cards_path(boards(:writebook)),
        params: { card: { title: "Backdated card without last_active_at", created_at: created_time, due_on: 1.week.from_now } },
        as: :json
      assert_response :created
    end

    card = Card.last
    assert_equal created_time, card.created_at
    assert_equal created_time, card.last_active_at
  end

  test "update as JSON with custom last_active_at" do
    card = cards(:logo)
    custom_time = Time.utc(2024, 3, 15, 14, 0, 0)

    put board_card_path(card.board, card, format: :json), params: { card: { last_active_at: custom_time } }

    assert_response :success
    assert_equal custom_time, card.reload.last_active_at
  end

  test "update as JSON can restore last_active_at after notes overwrite it" do
    created_time = Time.utc(2024, 1, 15, 10, 30, 0)
    last_active_time = Time.utc(2024, 6, 1, 12, 0, 0)

    # Create a card with custom timestamps (simulating import)
    post board_cards_path(boards(:writebook)),
      params: { card: { title: "Imported card", created_at: created_time, last_active_at: last_active_time, due_on: 1.week.from_now } },
      as: :json
    assert_response :created

    card = Card.last

    # Adding a note overwrites last_active_at (this is expected)
    card.notes.create!(creator: users(:kevin), body: "Imported note")
    assert_not_equal last_active_time, card.reload.last_active_at

    # After import, restore the correct last_active_at
    put board_card_path(card.board, card, format: :json), params: { card: { last_active_at: last_active_time } }
    assert_response :success

    assert_equal last_active_time, card.reload.last_active_at
  end

  test "update as JSON" do
    card = cards(:logo)

    put board_card_path(card.board, card, format: :json), params: { card: { title: "Update test" } }
    assert_response :success

    assert_equal "Update test", card.reload.title
  end

  test "delete as JSON" do
    card = cards(:logo)

    delete board_card_path(card.board, card, format: :json)
    assert_response :no_content

    assert_not Card.exists?(card.id)
  end
end
