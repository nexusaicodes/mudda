require "test_helper"

class Cards::NotesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create" do
    assert_difference -> { cards(:logo).notes.count }, +1 do
      post card_notes_path(cards(:logo)), params: { note: { body: "Agreed." } }, as: :turbo_stream
    end

    assert_response :success
  end

  test "create on draft card is forbidden" do
    draft_card = boards(:writebook).cards.create!(status: :drafted, creator: users(:kevin))

    assert_no_difference -> { draft_card.notes.count } do
      post card_notes_path(draft_card), params: { note: { body: "This should be forbidden" } }, as: :json
    end

    assert_response :forbidden
  end

  test "update" do
    put card_note_path(cards(:logo), notes(:logo_agreement_kevin)), params: { note: { body: "I've changed my mind" } }, as: :turbo_stream

    assert_response :success
    assert_action_text "I've changed my mind", notes(:logo_agreement_kevin).reload.body
  end

  test "update another user's note" do
    assert_no_changes -> { notes(:logo_agreement_jz).reload.body.to_s } do
      put card_note_path(cards(:logo), notes(:logo_agreement_jz)), params: { note: { body: "I've changed my mind" } }, as: :turbo_stream
    end

    assert_response :forbidden
  end

  test "index as JSON" do
    card = cards(:logo)

    get card_notes_path(card), as: :json

    assert_response :success
    assert_equal card.notes.count, @response.parsed_body["data"].count
  end

  test "create as JSON" do
    card = cards(:logo)

    assert_difference -> { card.notes.count }, +1 do
      post card_notes_path(card), params: { note: { body: "New note" } }, as: :json
    end

    assert_response :created
    assert_equal card_note_path(card, Note.last, format: :json), @response.headers["Location"]
    assert_equal Note.last.id, @response.parsed_body["id"]
  end

  test "create as JSON with custom created_at" do
    card = cards(:logo)
    custom_time = Time.utc(2024, 1, 15, 10, 30, 0)

    assert_difference -> { card.notes.count }, +1 do
      post card_notes_path(card), params: { note: { body: "Backdated note", created_at: custom_time } }, as: :json
    end

    assert_response :created
    assert_equal custom_time, Note.last.created_at
  end

  test "show as JSON" do
    note = notes(:logo_agreement_kevin)

    get card_note_path(note.card, note), as: :json

    assert_response :success
    assert_equal note.id, @response.parsed_body["id"]
    assert_equal note.card.id, @response.parsed_body.dig("card", "id")
    assert_equal card_url(note.card), @response.parsed_body.dig("card", "url")
    assert_equal card_note_url(note.card, note), @response.parsed_body["url"]
  end

  test "create as JSON with flat params" do
    card = cards(:logo)

    assert_difference -> { card.notes.count }, +1 do
      post card_notes_path(card), params: { body: "Flat note" }, as: :json
    end

    assert_response :created
    assert_equal "Flat note", Note.last.body.to_plain_text
  end

  test "update as JSON with flat params" do
    note = notes(:logo_agreement_kevin)

    put card_note_path(cards(:logo), note), params: { body: "Flat update" }, as: :json

    assert_response :success
    assert_equal "Flat update", note.reload.body.to_plain_text

    json = @response.parsed_body
    assert_equal note.id, json["id"]
    assert_equal "Flat update", json["body"]["plain_text"]
  end

  test "update as JSON" do
    note = notes(:logo_agreement_kevin)

    put card_note_path(cards(:logo), note), params: { note: { body: "Updated note" } }, as: :json

    assert_response :success
    assert_equal "Updated note", note.reload.body.to_plain_text

    json = @response.parsed_body
    assert_equal note.id, json["id"]
    assert_equal "Updated note", json["body"]["plain_text"]
    assert_equal note.creator.id, json["creator"]["id"]
  end

  test "destroy as JSON" do
    note = notes(:logo_agreement_kevin)

    delete card_note_path(cards(:logo), note), as: :json

    assert_response :no_content
    assert_not Note.exists?(note.id)
  end
end
