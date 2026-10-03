require "application_system_test_case"

class CardCompositionTest < ApplicationSystemTestCase
  setup { sign_in_as(users(:david)) }

  test "composing a card creates it in one request, with its steps" do
    visit new_board_card_url(boards(:writebook))

    fill_in "card_title", with: "Composed in one go"
    fill_in_lexxy with: "The whole thing arrives together"
    fill_in "card_due_on", with: 1.week.from_now.to_date
    fill_in "Add a step…", with: "First step"

    assert_difference -> { Card.count }, +1 do
      click_on "Create card"
      assert_current_path %r{/boards/\d+/cards/\d+}
    end

    card = Card.order(:id).last
    assert_equal "Composed in one go", card.title
    assert_equal [ "First step" ], card.steps.map(&:content)
  end

  # The form is the only place the card lives until it is submitted, so a reload has to bring
  # it back.
  test "a reload restores the form" do
    visit new_board_card_url(boards(:writebook))

    fill_in "card_title", with: "Half-written"
    fill_in_lexxy with: "Some context I do not want to retype"
    assert_saved_locally "new-card-#{boards(:writebook).id}", including: "retype"

    visit new_board_card_url(boards(:writebook))

    assert_field "card_title", with: "Half-written"
    assert_selector "lexxy-editor", text: "Some context I do not want to retype"
  end

  # Step rows are fields that repeat under one name, and a restored form can hold more of
  # them than the page was rendered with.
  test "a reload restores typed steps, rows and all" do
    visit new_board_card_url(boards(:writebook))

    fill_in "Add a step…", with: "First step"
    click_on "Add a step"
    all("input.step__content").last.set "Second step"
    assert_saved_locally "new-card-#{boards(:writebook).id}", including: "Second step"

    visit new_board_card_url(boards(:writebook))

    assert_equal [ "First step", "Second step" ],
      all("input.step__content").map { |field| field.value }.reject(&:blank?)
  end

  test "restored steps are submitted with the card" do
    visit new_board_card_url(boards(:writebook))

    fill_in "card_title", with: "Restored and shipped"
    fill_in "card_due_on", with: 1.week.from_now.to_date
    fill_in "Add a step…", with: "Survived the reload"
    assert_saved_locally "new-card-#{boards(:writebook).id}", including: "Survived the reload"

    visit new_board_card_url(boards(:writebook))
    click_on "Create card"
    assert_current_path %r{/boards/\d+/cards/\d+}

    assert_equal [ "Survived the reload" ], Card.order(:id).last.steps.map(&:content)
  end

  test "creating the card clears what the form had saved" do
    visit new_board_card_url(boards(:writebook))

    fill_in "card_title", with: "Transient"
    fill_in_lexxy with: "Gone once it is real"
    fill_in "card_due_on", with: 1.week.from_now.to_date
    assert_saved_locally "new-card-#{boards(:writebook).id}"

    click_on "Create card"
    assert_current_path %r{/boards/\d+/cards/\d+}

    visit new_board_card_url(boards(:writebook))
    assert_field "card_title", with: ""
  end

  private
    # The form is saved on a debounce, so wait for it to land rather than racing it. Pass
    # `including` when something was already saved under the key and the new value is what
    # needs waiting for.
    def assert_saved_locally(key, including: nil)
      assert_eventually do
        saved = page.evaluate_script("localStorage.getItem('#{key}')")
        saved.present? && (including.nil? || saved.include?(including))
      end
    end

    def assert_eventually(timeout: Capybara.default_max_wait_time)
      deadline = Time.current + timeout
      until yield
        flunk "condition was never met within #{timeout}s" if Time.current > deadline
        sleep 0.1
      end
    end
end
