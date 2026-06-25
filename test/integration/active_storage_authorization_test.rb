require "test_helper"

class ActiveStorageAuthorizationTest < ActionDispatch::IntegrationTest
  setup do
    Current.session = sessions(:david)
    @account = accounts("37s")
    @board = boards(:writebook)
    @card = cards(:logo)
    @blob = attach_blob_to_card(@card)
  end

  test "authenticated user can view blob" do
    sign_in_as :david

    get rails_blob_path(@blob, disposition: :inline)
    assert_response :redirect
    assert_match %r{rails/active_storage}, response.location
  end

  test "bearer token can view blob" do
    bearer_token = { "HTTP_AUTHORIZATION" => "Bearer #{identity_access_tokens(:davids_api_token).token}" }

    get rails_blob_path(@blob, disposition: :inline), env: bearer_token

    assert_response :redirect
    assert_match %r{rails/active_storage}, response.location
  end

  test "user from another account cannot view blob" do
    sign_in_as :mike

    get rails_blob_path(@blob, disposition: :inline)
    assert_response :forbidden
  end

  test "unauthenticated user cannot view blob" do
    get rails_blob_path(@blob, disposition: :inline)
    assert_response :redirect
    assert_match %r{/session/new}, response.location
  end

  test "authenticated user can view representation" do
    sign_in_as :david

    get rails_representation_path(@blob.representation(resize_to_limit: [ 100, 100 ]))
    assert_response :redirect
    assert_match %r{rails/active_storage/}, response.location
  end

  test "bearer token can view representation" do
    bearer_token = { "HTTP_AUTHORIZATION" => "Bearer #{identity_access_tokens(:davids_api_token).token}" }

    get rails_representation_path(@blob.representation(resize_to_limit: [ 100, 100 ])), env: bearer_token

    assert_response :redirect
    assert_match %r{rails/active_storage/}, response.location
  end

  test "user from another account cannot view representation" do
    sign_in_as :mike

    get rails_representation_path(@blob.representation(resize_to_limit: [ 100, 100 ]))
    assert_response :forbidden
  end

  # Rich text embeds in cards

  test "authenticated user can view rich text embed in card" do
    sign_in_as :david

    blob = attach_blob_as_rich_text_embed(@card)

    get rails_blob_path(blob, disposition: :inline)
    assert_response :redirect
    assert_match %r{rails/active_storage}, response.location
  end

  test "user from another account cannot view rich text embed in card" do
    sign_in_as :mike

    blob = attach_blob_as_rich_text_embed(@card)

    get rails_blob_path(blob, disposition: :inline)
    assert_response :forbidden
  end

  # Rich text embeds in notes

  test "authenticated user can view rich text embed in note" do
    sign_in_as :david

    note = notes(:logo_1)
    blob = attach_blob_as_rich_text_embed(note)

    get rails_blob_path(blob, disposition: :inline)
    assert_response :redirect
    assert_match %r{rails/active_storage}, response.location
  end

  test "user from another account cannot view rich text embed in note" do
    sign_in_as :mike

    note = notes(:logo_1)
    blob = attach_blob_as_rich_text_embed(note)

    get rails_blob_path(blob, disposition: :inline)
    assert_response :forbidden
  end

  test "unauthenticated user can view avatar" do
    blob = attach_avatar_to(users(:david))

    get rails_blob_path(blob, disposition: :inline)
    assert_response :redirect
    assert_match %r{rails/active_storage}, response.location
  end

  test "unauthenticated user can view avatar thumbnail" do
    blob = attach_avatar_to(users(:david))

    get rails_representation_path(blob.representation(resize_to_fill: [ 256, 256 ]))
    assert_response :redirect
    assert_match %r{rails/active_storage}, response.location
  end

  test "proxy for non-public blob does not set public Cache-Control" do
    sign_in_as :david

    get rails_storage_proxy_path(@blob)
    assert_response :success
    assert_not_includes response.headers["Cache-Control"], "public"
  end

  test "proxy for publicly accessible blob sets public Cache-Control" do
    blob = attach_avatar_to(users(:david))

    get rails_storage_proxy_path(blob)
    assert_response :success
    assert_includes response.headers["Cache-Control"], "public"
  end

  test "representation proxy for non-public blob does not set public Cache-Control" do
    sign_in_as :david

    get rails_storage_proxy_path(@blob.representation(resize_to_limit: [ 100, 100 ]))
    assert_response :success
    assert_not_includes response.headers["Cache-Control"], "public"
  end

  test "representation proxy for publicly accessible blob sets public Cache-Control" do
    blob = attach_avatar_to(users(:david))

    get rails_storage_proxy_path(blob.representation(resize_to_fill: [ 256, 256 ]))
    assert_response :success
    assert_includes response.headers["Cache-Control"], "public"
  end

  private
    def attach_blob_to_card(card)
      Current.with(session: sessions(:david)) do
        card.image.attach io: file_fixture("moon.jpg").open, filename: "test.jpg", content_type: "image/jpeg"
        card.image.blob
      end
    end

    def attach_blob_as_rich_text_embed(container)
      Current.with(account: @account, session: sessions(:david)) do
        blob = ActiveStorage::Blob.create_and_upload! \
          io: file_fixture("moon.jpg").open,
          filename: "embed.jpg",
          content_type: "image/jpeg"

        attachment_html = ActionText::Attachment.from_attachable(blob).to_html
        if container.respond_to?(:description)
          container.update!(description: "<p>Description with image: #{attachment_html}</p>")
        else
          container.update!(body: "<p>Body with image: #{attachment_html}</p>")
        end

        blob.reload
      end
    end

    def attach_avatar_to(user)
      Current.with(account: @account, session: sessions(:david)) do
        user.avatar.attach io: file_fixture("moon.jpg").open, filename: "avatar.jpg", content_type: "image/jpeg"
        user.avatar.blob
      end
    end
end
