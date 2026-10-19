require "test_helper"

class User::NamedTest < ActiveSupport::TestCase
  test "initials" do
    assert_initials "M", name: "Michael"
    assert_initials "SD", name: "Salvador Dali"
    assert_initials "LMM", name: "Lin-Manuel Miranda"
    assert_initials "OCD", name: "O'Conor Díez"
    assert_initials "ACG", name: "Anne Christine García"
    assert_initials "ÁL", name: "Ángela López"
  end

  private
    def assert_initials(expected, **attributes)
      assert_equal expected, User.new(attributes).initials
    end
end
