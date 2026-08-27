require "test_helper"

class ActiveStorage::DirectUploadsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @blob_params = {
      blob: {
        filename: "screenshot.png",
        byte_size: 12345,
        checksum: "GQ5SqLsM7ylnji0Wgd9wNC==",
        content_type: "image/png"
      }
    }
  end

  test "create" do
    sign_in_as :david

    post rails_direct_uploads_path,
      params: @blob_params,
      as: :json

    assert_response :success
    assert_includes response.parsed_body.keys, "direct_upload"
  end

  test "create with session token skips forgery protection" do
    sign_in_as :david

    with_forgery_protection do
      post rails_direct_uploads_path,
        params: @blob_params,
        as: :json

      assert_response :success
      assert_includes response.parsed_body.keys, "direct_upload"
    end
  end

  test "create with session token from a cross-site request is forbidden" do
    sign_in_as :david

    with_forgery_protection do
      post rails_direct_uploads_path,
        params: @blob_params,
        headers: { "Sec-Fetch-Site" => "cross-site" },
        as: :json

      assert_response :unprocessable_entity
    end
  end

  test "create unauthenticated" do
    post rails_direct_uploads_path,
      params: @blob_params,
      as: :json

    assert_response :redirect
  end

  # Cross-account uploads used to be reachable by swapping the account slug in the URL.
  # The account now follows the signed-in identity, so the guard that remains is the one
  # against a deactivated user.
  test "create as a deactivated user is forbidden" do
    sign_in_as :david
    users(:david).update!(active: false)

    post rails_direct_uploads_path, params: @blob_params, as: :json

    assert_response :forbidden
  end

  private
    def with_forgery_protection
      original = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      yield
    ensure
      ActionController::Base.allow_forgery_protection = original
    end
end
