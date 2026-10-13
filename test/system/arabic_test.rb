require "application_system_test_case"

class ArabicTest < ApplicationSystemTestCase
  setup do
    users(:kevin).settings.update!(locale: "ar")
    sign_in_as(users(:kevin))
  end

  test "the board reads right to left with Arabic lane names" do
    visit board_url(boards(:writebook))

    assert_selector "html[lang=ar][dir=rtl]", visible: :all
    assert_text I18n.t("lanes.doing", locale: :ar)
    assert_selector "[data-column-name=Doing]", visible: :all
  end

  test "the back link reads in Arabic" do
    visit cards_url(column_ids: [ columns(:writebook_doing).id ])
    click_on cards(:text).title

    assert_selector "a.btn--back", text: "العودة إلى"
  end

  test "search finds Arabic text without its vowel marks or article" do
    card = Current.set(session: users(:kevin).sessions.first) do
      boards(:writebook).cards.create!(title: "مَرْحَباً بالكتاب", creator: users(:kevin))
    end

    visit search_url(q: "مرحبا كتاب")

    assert_text card.title
  end
end
