require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  def parse(html)
    Nokogiri::HTML::DocumentFragment.parse(html)
  end

  test "page_title_tag without a page title" do
    assert_select parse(page_title_tag), "title", text: "Mudda"
  end

  test "page_title_tag with a page title" do
    @page_title = "Holodeck"

    assert_select parse(page_title_tag), "title", text: "Holodeck | Mudda"
  end

  test "last_board_storage_key is scoped to the account" do
    account = accounts("37s")

    assert_equal "mudda:last-board:#{account.external_account_id}", last_board_storage_key(account)
  end
end
