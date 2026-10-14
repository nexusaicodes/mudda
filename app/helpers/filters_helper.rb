module FiltersHelper
  def filter_title(title)
    tag.strong title, class: "popup__title pad-inline-half", tabindex: "-1", data: { dialog_target: "focusTouch" }
  end
end
