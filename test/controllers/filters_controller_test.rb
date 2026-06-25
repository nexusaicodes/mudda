require "test_helper"

class FiltersControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :david
  end

  test "create" do
    assert_difference "users(:david).filters.count", +1 do
      post filters_path, params: {
        terms: [ "haggis" ],
        board_ids: [ boards(:writebook).id ] }, as: :turbo_stream
    end
    assert_response :success

    filter = Filter.last
    assert_equal [ "haggis" ], filter.terms
    assert_equal [ boards(:writebook) ], filter.boards
  end

  test "destroy" do
    filter = filters(:newest_first)

    assert_difference "users(:david).filters.count", -1 do
      delete filter_path(filter), as: :turbo_stream
    end
    assert_response :success
  end
end
