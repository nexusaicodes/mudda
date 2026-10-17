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
end
