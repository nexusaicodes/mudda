require "test_helper"

class IdentityTest < ActiveSupport::TestCase
  test "owner resolves the identity MUDDA_OWNER_EMAIL names" do
    with_owner_email identities(:david).email_address do
      assert_equal identities(:david), Identity.owner
    end
  end

  test "owner is nobody when MUDDA_OWNER_EMAIL names no one" do
    with_owner_email "nobody@example.com" do
      assert_nil Identity.owner
    end
  end

  test "owner falls back to the sole identity only when there is one" do
    with_owner_email nil do
      assert_nil Identity.owner

      Identity.where.not(id: identities(:david)).destroy_all

      assert_equal identities(:david), Identity.owner
    end
  end

  test "email address format validation" do
    invalid_emails = [
      "sam smith@example.com",       # space in local part
      "@example.com",                # missing local part
      "test@",                       # missing domain
      "test",                        # missing @ and domain
      "<script>@example.com",        # angle brackets
      "test@example.com\nX-Inject:" # newline (header injection attempt)
    ]

    invalid_emails.each do |email|
      identity = Identity.new(email_address: email)
      assert_not identity.valid?, "expected #{email.inspect} to be invalid"
      assert identity.errors[:email_address].any?, "expected error on email_address for #{email.inspect}"
    end
  end

  test "destroy deactivates users before nullifying identity" do
    identity = identities(:kevin)
    user = users(:kevin)

    assert_predicate user, :active?

    identity.destroy!
    user.reload

    assert_nil user.identity_id, "identity should be nullified"
    assert_not_predicate user, :active?
  end

  private
    def with_owner_email(email_address)
      original = ENV["MUDDA_OWNER_EMAIL"]
      ENV["MUDDA_OWNER_EMAIL"] = email_address
      yield
    ensure
      ENV["MUDDA_OWNER_EMAIL"] = original
    end
end
