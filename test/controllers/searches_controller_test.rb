require "test_helper"

class SearchesControllerTest < ActionDispatch::IntegrationTest
  include SearchTestHelper

  setup do
    @card = @board.cards.create!(title: "Layout is broken", description: "Look at this mess.", due_on: 1.week.from_now, creator: @user)
    @note_card = @board.cards.create!(title: "Some card", due_on: 1.week.from_now, creator: @user)
    @note_card.notes.create!(body: "overflowing text issue", creator: @user)
    @note2_card = @board.cards.create!(title: "Just haggis", description: "More haggis", due_on: 1.week.from_now, creator: @user)
    @note2_card.notes.create!(body: "I love haggis", creator: @user)

    sign_in_as @user
  end

  test "search" do
    # Search query is blank
    get search_path(q: "")
    assert @query.nil?

    # Searching by card title
    get search_path(q: "broken")
    assert_select "li .search__title", text: /Layout is broken/
    assert_select "li .search__excerpt", text: /Look at this mess/

    # Searching by note
    get search_path(q: "overflowing")
    assert_select "li .search__title", text: /Some card/
    assert_select "li .search__excerpt--note", text: /overflowing text issue/

    # A card that matched in its description and a note shows once, by its description
    get search_path(q: "haggis")
    assert_select "li .search__title", text: /Just haggis/, count: 1
    assert_select "li .search__excerpt", text: /More haggis/
    assert_match(/<mark class="circled-text"><span><\/span>haggis<\/mark>/, response.body)

    get search_path(q: "nothingmatchesthis")
    assert_select ".search__blank-slate", text: "No matches"
  end

  test "results are grouped by board, the board searched from first" do
    Current.user = @user
    other = @user.account.boards.create!(name: "Elsewhere", creator: @user)
    2.times { |i| other.cards.create!(title: "Broken thing #{i}", creator: @user) }

    get search_path(q: "broken")
    assert_select ".search__group-title", count: 2
    assert_select ".search__group:first-child .search__group-title", text: /Elsewhere\s*2/

    get search_path(q: "broken"), headers: { "Referer" => board_url(@board) }
    assert_select ".search__group:first-child .search__group-title", text: /#{@board.name}\s*1/
  end

  test "a board with more than five matches links to the rest" do
    Current.user = @user
    6.times { |i| @board.cards.create!(title: "Broken widget #{i}", creator: @user) }

    get search_path(q: "broken")
    assert_select ".search__group:first-child .search__list li", count: 5
    assert_select "a.search__more[href=?]", cards_path(board_ids: [ @board.id ], terms: [ "broken" ]), text: "Show all 7 →"
  end

  test "a card number is searched like any other text, never jumped to" do
    get search_path(q: @card.number)
    assert_response :success
    assert_select "form[data-controller='auto-submit']", count: 0
  end

  test "search as JSON" do
    get search_path(q: "broken"), as: :json
    assert_response :success

    body = @response.parsed_body["data"]
    assert_kind_of Array, body
    assert_equal 1, body.size
    assert_equal "Layout is broken", body.first["title"]
  end

  test "FTS5 operators are searched for as words" do
    @board.cards.create!(title: "Ship it OR NOT", due_on: 1.week.from_now, creator: @user)

    %w[ OR NOT AND NEAR ].each do |operator|
      get search_path(q: operator), as: :json
      assert_response :success, "#{operator} alone"
    end

    get search_path(q: "broken OR haggis NOT"), as: :json
    assert_response :success
    assert_empty @response.parsed_body["data"], "the operators are words the cards must contain too"

    get search_path(q: "ship OR not"), as: :json
    assert_equal [ "Ship it OR NOT" ], @response.parsed_body["data"].pluck("title")

    get search_path(q: "NEAR(broken haggis)")
    assert_response :success
  end

  test "a search FTS5 can't parse is a 422, not a crash" do
    Search::Query.any_instance.stubs(:match_expression).returns(%("broken" OR))

    assert_no_error_reported do
      get search_path(q: "broken"), as: :json
    end
    assert_response :unprocessable_entity
    assert_equal [ "is not a valid search" ], @response.parsed_body.dig("errors", "q")

    get search_path(q: "broken")
    assert_response :unprocessable_entity
  end

  test "search as JSON deduplicates cards with multiple search hits" do
    get search_path(q: "haggis"), as: :json
    assert_response :success

    body = @response.parsed_body["data"]
    assert_kind_of Array, body
    assert_equal 1, body.size
    assert_equal @note2_card.id, body.first["id"]
  end

  test "search highlights matched terms with proper HTML marks" do
    @board.cards.create!(title: "Testing search highlighting", due_on: 1.week.from_now, creator: @user)

    get search_path(q: "highlighting")
    assert_response :success
  end

  test "search preserves highlight marks but escapes surrounding HTML" do
    @board.cards.create!(
      title: "<b>Bold</b> testing content", due_on: 1.week.from_now,
      creator: @user
    )

    get search_path(q: "testing")
    assert_response :success

    # Should escape <b> tags
    assert response.body.include?("&lt;b&gt;")
    # But should preserve highlight marks around "testing"
    assert_match(/<mark class="circled-text"><span><\/span>testing<\/mark>/, response.body)
  end
end
