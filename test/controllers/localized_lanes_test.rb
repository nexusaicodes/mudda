require "test_helper"

class LocalizedLanesTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :david
  end

  test "an Arabic-locale board shows Arabic lane labels and keeps English lane data" do
    users(:david).settings.update!(locale: "ar")

    get board_path(boards(:writebook))

    assert_response :success
    assert_select ".cards__expander-title", text: /قيد التنفيذ/
    assert_select "[data-column-name='Doing']"
    assert_select "[data-column-name='قيد التنفيذ']", count: 0
  end

  test "a card fragment cached in English is not reused in Arabic" do
    card = cards(:logo)

    with_fragment_caching do
      get board_card_path(card.board, card)
      assert_select ".card-perma__bg", text: /Due /

      users(:david).settings.update!(locale: "ar")
      get board_card_path(card.board, card)

      assert_select ".card-perma__bg", text: /الاستحقاق/
      assert_select ".card-perma__bg", text: /Due /, count: 0
    end
  end

  private
    def with_fragment_caching
      caching, store = ActionController::Base.perform_caching, ActionController::Base.cache_store
      ActionController::Base.perform_caching = true
      ActionController::Base.cache_store = ActiveSupport::Cache::MemoryStore.new
      yield
    ensure
      ActionController::Base.perform_caching = caching
      ActionController::Base.cache_store = store
    end
end
