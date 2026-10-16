require "test_helper"

# What db/seeds.rb prints reaches a deployment's logs, so it names the owner by masked email.
class SeedsTest < ActiveSupport::TestCase
  test "the seed names the owner by masked email" do
    owner = User.order(:id).first

    output = capture_io do
      with_env("MUDDA_OWNER_EMAIL" => owner.email_address) { load Rails.root.join("db/seeds.rb") }
    end.first

    assert_includes output, StructuredLog.mask_email(owner.email_address)
    assert_not_includes output, owner.email_address
  end

  test "refusing a second owner names neither email in full" do
    owner = User.order(:id).first

    errors = capture_io do
      assert_raises(SystemExit) do
        with_env("MUDDA_OWNER_EMAIL" => "someone-else@example.com") { load Rails.root.join("db/seeds.rb") }
      end
    end.last

    assert_includes errors, "s***@example.com"
    assert_not_includes errors, "someone-else@example.com"
    assert_not_includes errors, owner.email_address
  end
end
