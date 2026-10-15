require "test_helper"

class My::PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup do
    My::PasswordsController::RATE_LIMIT_STORE.clear
    sign_in_as :kevin
  end

  test "edit" do
    get edit_my_password_path
    assert_response :success
  end

  test "changing the password keeps this browser and signs out the others" do
    other_browser = users(:kevin).sessions.create!
    token = users(:kevin).sessions.create!(kind: :token, label: "agent", scopes: "read")

    patch my_password_path, params: { current_password: owner_password, user: { password: "brand-new-pw", password_confirmation: "brand-new-pw" } }

    assert_redirected_to user_path(users(:kevin))
    assert_equal users(:kevin), OwnerPassword.authenticate(users(:kevin).email_address, "brand-new-pw")
    assert_nil OwnerPassword.authenticate(users(:kevin).email_address, owner_password)
    assert_not Session.exists?(other_browser.id)
    assert Session.exists?(token.id)

    get edit_my_password_path
    assert_response :success
  end

  test "a wrong current password changes nothing" do
    patch my_password_path, params: { current_password: "not-it", user: { password: "brand-new-pw", password_confirmation: "brand-new-pw" } }

    assert_response :unprocessable_entity
    assert_nil users(:kevin).reload.password_digest
  end

  test "a short or mismatched new password is refused" do
    patch my_password_path, params: { current_password: owner_password, user: { password: "short", password_confirmation: "short" } }
    assert_response :unprocessable_entity

    patch my_password_path, params: { current_password: owner_password, user: { password: "brand-new-pw", password_confirmation: "other-new-pw" } }
    assert_response :unprocessable_entity

    assert_nil users(:kevin).reload.password_digest
  end

  test "a token can't change the password" do
    patch my_password_path, params: { current_password: owner_password, user: { password: "brand-new-pw", password_confirmation: "brand-new-pw" } },
      headers: bearer_headers_for(:kevin)

    assert_response :forbidden
    assert_nil users(:kevin).reload.password_digest
  end
end
