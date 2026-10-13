require "test_helper"

class My::LocalesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "update" do
    patch my_locale_path, params: { locale: "ar" }

    assert_redirected_to user_path(users(:kevin))
    assert_equal "ar", users(:kevin).reload.locale
  end

  test "a blank locale follows the browser" do
    users(:kevin).settings.update!(locale: "ar")

    patch my_locale_path, params: { locale: "" }

    assert_nil users(:kevin).reload.locale
  end
end
