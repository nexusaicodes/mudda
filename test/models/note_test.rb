require "test_helper"

class NoteTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  # Every card takes notes: there is no state a card can be in that refuses them.
  test "any card takes notes" do
    assert_difference -> { cards(:unfinished_thoughts).notes.count }, +1 do
      cards(:unfinished_thoughts).notes.create!(body: "Perfectly allowed")
    end
  end

  test "rich text embed variants are processed immediately on attachment" do
    note = cards(:logo).notes.create!(body: "Check this out")
    note.body.body.attachables # force load

    blob = ActiveStorage::Blob.create_and_upload! \
      io: File.open(file_fixture("moon.jpg")),
      filename: "moon.jpg",
      content_type: "image/jpeg"

    note.body.body = ActionText::Content.new(note.body.body.to_html).append_attachables(blob)
    note.save!

    embed = note.body.embeds.sole

    Attachments::VARIANTS.each_key do |variant_name|
      variant = embed.variant(variant_name)
      assert variant.processed?, "Expected #{variant_name} variant to be processed immediately"
    end
  end
end
