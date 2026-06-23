require "test_helper"

class FiltersControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :david
  end

  test "create" do
    assert_difference "users(:david).filters.count", +1 do
      post filters_path, params: {
        assignment_status: "unassigned",
        assignee_ids: [ users(:jz).id ],
        board_ids: [ boards(:writebook).id ] }, as: :turbo_stream
    end
    assert_response :success

    filter = Filter.last
    assert_predicate filter.assignment_status, :unassigned?
    assert_equal [ users(:jz) ], filter.assignees
    assert_equal [ boards(:writebook) ], filter.boards
  end

  test "destroy" do
    filter = filters(:jz_assignments)
    expected_params = filter.as_params

    assert_difference "users(:david).filters.count", -1 do
      delete filter_path(filter), as: :turbo_stream
    end
    assert_response :success
  end
end
