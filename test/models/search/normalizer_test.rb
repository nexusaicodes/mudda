require "test_helper"

class Search::NormalizerTest < ActiveSupport::TestCase
  test "strips harakat and tatweel" do
    assert_equal "مرحبا", normalize("مَرْحَباً")
    assert_equal "كتاب", normalize("كتـــاب")
  end

  test "folds hamza forms, alef maqsura and taa marbuta" do
    assert_equal "احمد اسلام امن", normalize("أحمد إسلام آمن")
    assert_equal "الي مدرسه", normalize("إلى مدرسة")
  end

  test "strips the definite article and its prefixed forms" do
    assert_equal "كتاب كتاب كتاب كتاب كتاب", normalize("الكتاب والكتاب بالكتاب كالكتاب فالكتاب")
    assert_equal "لطلاب", normalize("للطلاب")
  end

  test "keeps the article when fewer than two letters would remain" do
    assert_equal "ال الي", normalize("ال الى")
  end

  test "leaves Latin text untouched" do
    assert_equal "Running Café tests", normalize("Running Café tests")
    assert_nil normalize(nil)
  end

  private
    def normalize(text)
      Search::Normalizer.normalize(text)
    end
end
