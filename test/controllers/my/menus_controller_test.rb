require "test_helper"

class My::MenusControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
    @user = users(:kevin)
    @account = accounts("37s")
  end

  test "lists every board, ticking the one you are on" do
    get my_menu_path(board_id: boards(:writebook).id)

    assert_response :success
    @user.boards.each { |board| assert_select ".popup__item a[href=?]", board_path(board) }
    assert_select ".popup__item--current a[href=?]", board_path(boards(:writebook))
    assert_select ".popup__item--current", count: 1
  end

  test "offers the cross-board views with what each holds" do
    Current.user = @user
    cards(:logo).update!(due_on: Date.yesterday)

    get my_menu_path

    due_soon = Filter.new(@user, due: "soon").cards.count
    assert_operator due_soon, :>, 0
    assert_select "a[href=?]", cards_path(due: "soon") do
      assert_select ".menu__count", text: due_soon.to_s
    end
    assert_select "a[href=?]", cards_path(lane: "doing")
    assert_select "a[href=?]", cards_path(indexed_by: "pinned")
  end

  test "new board closes the boards section, and nothing else is offered" do
    get my_menu_path

    assert_select "turbo-frame#my_menu" do
      assert_select ".nav__section:first-of-type li:last-child a[href=?]", new_board_path, text: "New board"
      assert_select "input", count: 0
      assert_select ".menu__note", count: 0
    end
  end

  test "ticks the view you are on, and dims a view with nothing in it" do
    Card.update_all(pinned: false)

    get my_menu_path(view: "pinned")

    assert_select ".popup__item--current a[href=?]", cards_path(indexed_by: "pinned")
    assert_select ".popup__item--muted a[href=?]", cards_path(indexed_by: "pinned")
  end

  test "offers to delete the board you are on, and only then" do
    get my_menu_path(board_id: boards(:writebook).id)
    assert_select ".menu__footer form[action=?]", board_path(boards(:writebook))

    get my_menu_path
    assert_select ".menu__footer", count: 0
  end

  test "etag invalidates when boards change" do
    get my_menu_path
    etag = response.headers["ETag"]

    @account.boards.create!(name: "New Board", creator: @user)

    get my_menu_path, headers: { "If-None-Match" => etag }
    assert_response :success
  end

  test "etag invalidates when a card changes" do
    get my_menu_path
    etag = response.headers["ETag"]

    travel 1.second
    cards(:logo).update!(due_on: Date.tomorrow)

    get my_menu_path, headers: { "If-None-Match" => etag }
    assert_response :success
  end

  test "etag returns not modified when nothing changes" do
    get my_menu_path
    etag = response.headers["ETag"]

    get my_menu_path, headers: { "If-None-Match" => etag }
    assert_response :not_modified
  end
end
