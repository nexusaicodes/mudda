require "test_helper"

class Card::PromptableTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "to_prompt renders metadata without stray braces" do
    card = cards(:logo)
    prompt = card.to_prompt

    assert_includes prompt, "* Created by: #{card.creator.name}\n"
    assert_includes prompt, "* Created at: #{card.created_at}\n"
    assert_not_includes prompt, "}}"
    assert_not_includes prompt, "#{card.creator.name}}"
  end
end
