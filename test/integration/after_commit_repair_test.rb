require "test_helper"

# A side effect that fails after its write committed is reported and repaired by a job, and
# the request that made the write still succeeds.
class AfterCommitRepairTest < ActionDispatch::IntegrationTest
  setup do
    @card = cards(:logo)
    @headers = bearer_headers_for(:kevin, label: "claude")
  end

  test "a note whose indexing fails is created, reported and indexed by the repair job" do
    Search::Record.stubs(:upsert!).raises(ActiveRecord::StatementInvalid, "index unavailable")

    assert_error_reported(ActiveRecord::StatementInvalid) do
      post board_card_notes_path(@card.board, @card), params: { note: { body: "Indexed later" } }, headers: @headers, as: :json
    end

    assert_response :created
    note = Note.find(@response.parsed_body["id"])
    assert_enqueued_with job: AfterCommitRepairJob, args: [ note, "reindex" ]
    assert_nil Search::Record.find_by(searchable_type: "Note", searchable_id: note.id)

    Search::Record.unstub(:upsert!)
    perform_enqueued_jobs only: AfterCommitRepairJob

    assert Search::Record.find_by(searchable_type: "Note", searchable_id: note.id)
  end

  test "a note whose event fails is created, and the repair records the event once, for its agent" do
    Note.any_instance.stubs(:track_creation).raises(ActiveRecord::StatementInvalid, "events unavailable")

    assert_error_reported(ActiveRecord::StatementInvalid) do
      post board_card_notes_path(@card.board, @card), params: { note: { body: "Evented later" } }, headers: @headers, as: :json
    end

    assert_response :created
    note = Note.find(@response.parsed_body["id"])
    assert_enqueued_with job: AfterCommitRepairJob, args: [ note, "track_creation", "claude" ]
    assert_not note.events.exists?

    Note.any_instance.unstub(:track_creation)
    perform_enqueued_jobs only: AfterCommitRepairJob
    note.track_creation("claude")

    assert_equal [ [ "note_created", "claude" ] ], note.events.pluck(:action, :agent_name)
  end

  test "an avatar whose variant fails is saved, reported and its variant queued" do
    sign_in_as :kevin
    ActiveStorage::VariantWithRecord.any_instance.stubs(:process_from_io).raises(Vips::Error, "corrupt")

    assert_error_reported(Vips::Error) do
      put user_path(users(:kevin)), params: { user: { avatar: fixture_file_upload("avatar.png", "image/png") } }
    end
    assert_enqueued_with job: ActiveStorage::CreateVariantsJob, args: ->(args) { args.first == users(:kevin).reload.avatar.blob }

    assert_redirected_to user_path(users(:kevin))
    assert users(:kevin).reload.avatar.attached?
  end

  test "a variant that can't be made serves the original" do
    sign_in_as :kevin
    users(:kevin).avatar.attach(fixture_file_upload("avatar.png", "image/png"))
    blob = users(:kevin).avatar.blob
    ActiveStorage::VariantWithRecord.any_instance.stubs(:processed).raises(Vips::Error, "corrupt")

    assert_error_reported(Vips::Error) do
      get rails_representation_path(blob.variant(resize_to_limit: [ 10, 10 ]))
    end

    assert_redirected_to rails_blob_path(blob)
  end
end
