require "test_helper"

class My::MenusControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
    @user = users(:kevin)
    @account = accounts("37s")
  end

  test "show" do
    get my_menu_path
    assert_response :success
  end

  test "the upgrade link shows only when the board has somewhere to upgrade" do
    get my_menu_path
    assert_select "a[href=?]", account_upgrade_path, count: 0

    with_env("MUDDA_UPGRADE_URL" => "https://mudda.example/upgrade/new?token=signed") { get my_menu_path }
    assert_select "a[href=?]", account_upgrade_path, text: "Upgrade for unlimited cards"
  end

  test "etag invalidates when the upgrade link comes or goes" do
    get my_menu_path
    etag = response.headers["ETag"]

    with_env("MUDDA_UPGRADE_URL" => "https://mudda.example/upgrade/new?token=signed") do
      get my_menu_path, headers: { "If-None-Match" => etag }
    end
    assert_response :success
  end

  test "etag invalidates when filters change" do
    get my_menu_path
    assert_response :success
    etag = response.headers["ETag"]

    @user.filters.create!(
      params_digest: Filter.digest_params({ indexed_by: :all, sorted_by: :newest }),
      fields: { indexed_by: :all, sorted_by: :newest }
    )

    get my_menu_path, headers: { "If-None-Match" => etag }
    assert_response :success
  end

  test "etag invalidates when boards change" do
    get my_menu_path
    assert_response :success
    etag = response.headers["ETag"]

    @account.boards.create!(name: "New Board", creator: @user)

    get my_menu_path, headers: { "If-None-Match" => etag }
    assert_response :success
  end

  test "etag returns not modified when nothing changes" do
    get my_menu_path
    assert_response :success
    etag = response.headers["ETag"]

    get my_menu_path, headers: { "If-None-Match" => etag }
    assert_response :not_modified
  end
end
