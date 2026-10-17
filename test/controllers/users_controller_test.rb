require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "show" do
    sign_in_as :kevin

    get user_path(users(:kevin))
    assert_in_body users(:kevin).name
  end

  test "the profile holds security and sign out, and no plan without a ceiling or an upgrade" do
    sign_in_as :kevin

    with_env("MUDDA_PLATFORM_KEYS" => nil) { get user_path(users(:kevin)) }
    assert_select "a[href=?]", my_passkeys_path
    assert_select "a[href=?]", my_tokens_path
    assert_select "a[href=?]", edit_my_password_path
    assert_select "form[action=?] button.settings__sign-out", session_path
    assert_select "a[href=?]", account_upgrade_path, count: 0
    assert_no_match "Plan", response.body
  end

  test "the profile offers no password change when there is no password to confirm" do
    sign_in_as :kevin

    with_env("MUDDA_OWNER_PASSWORD" => nil) { get user_path(users(:kevin)) }
    assert_select "a[href=?]", edit_my_password_path, count: 0
    assert_select "a[href=?]", my_passkeys_path
  end

  test "the profile shows the plan under a ceiling, and the upgrade whenever there is somewhere to go" do
    sign_in_as :kevin

    on_the_free_plan(upgrade_url: nil) { get user_path(users(:kevin)) }
    assert_in_body "of 100 used"
    assert_select "a[href=?]", account_upgrade_path, count: 0

    on_the_plan("premium", upgrade_url: "https://mudda.example/upgrade") { get user_path(users(:kevin)) }
    assert_select "a[href=?]", account_upgrade_path, text: "Upgrade for unlimited cards"
  end

  test "update oneself" do
    sign_in_as :kevin

    get edit_user_path(users(:kevin))
    assert_response :ok

    put user_path(users(:kevin)), params: { user: { name: "New Kevin" } }
    assert_redirected_to user_path(users(:kevin))
    assert_equal "New Kevin", users(:kevin).reload.name
  end

  test "update with invalid avatar content type shows validation error" do
    sign_in_as :kevin

    svg_file = fixture_file_upload("avatar.svg", "image/svg+xml")

    put user_path(users(:kevin)), params: { user: { avatar: svg_file } }
    assert_response :unprocessable_entity
    assert_select "form[action='#{user_path(users(:kevin))}']"
    assert_select ".txt-negative", text: /must be a JPEG, PNG, GIF, or WebP image/
  end

  test "update with oversized avatar shows validation error" do
    sign_in_as :kevin

    png_file = fixture_file_upload("avatar.png", "image/png")

    ActiveStorage::Analyzer::ImageAnalyzer::Vips.any_instance.stubs(:metadata).returns({ width: 5000, height: 100 })

    put user_path(users(:kevin)), params: { user: { avatar: png_file } }
    assert_response :unprocessable_entity
    assert_select ".txt-negative", text: /width must be less than 4096px/
  end

  test "update with valid avatar" do
    sign_in_as :kevin

    png_file = fixture_file_upload("avatar.png", "image/png")

    put user_path(users(:kevin)), params: { user: { avatar: png_file } }
    assert_redirected_to user_path(users(:kevin))
    assert users(:kevin).reload.avatar.attached?
    assert_equal "image/png", users(:kevin).avatar.content_type
  end

  test "show as JSON" do
    sign_in_as :kevin

    get user_path(users(:kevin)), as: :json
    assert_response :success
    assert_equal users(:kevin).name, @response.parsed_body["name"]
  end

  test "update as JSON" do
    sign_in_as :kevin

    put user_path(users(:kevin)), params: { user: { name: "New Kevin" } }, as: :json

    assert_response :success
    assert_equal "New Kevin", users(:kevin).reload.name

    json = @response.parsed_body
    assert_equal users(:kevin).id, json["id"]
    assert_equal "New Kevin", json["name"]
  end

  test "update as JSON with invalid avatar returns errors" do
    sign_in_as :kevin

    svg_file = fixture_file_upload("avatar.svg", "image/svg+xml")

    put user_path(users(:kevin), format: :json), params: { user: { avatar: svg_file } }

    assert_response :unprocessable_entity
    assert @response.parsed_body.dig("errors", "avatar").present?
  end
end
