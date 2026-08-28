require "test_helper"

class ActiveStorageAnalyzeJobSkipDetachedTest < ActiveSupport::TestCase
  test "skips analysis when blob has no attachments" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("x" * 1024), filename: "orphan.txt", content_type: "text/plain"
    )

    blob.expects(:analyze).never

    ActiveStorage::AnalyzeJob.perform_now(blob)
  end

  test "performs analysis when blob has attachments" do
    user = users(:david)
    user.avatar.attach io: file_fixture("avatar.png").open, filename: "test.png", content_type: "image/png"
    blob = user.avatar.blob

    blob.expects(:analyze).once

    ActiveStorage::AnalyzeJob.perform_now(blob)
  end
end
