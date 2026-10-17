module FiltersHelper
  def filter_title(title)
    tag.strong title, class: "menu-title px-2 text-sm", tabindex: "-1", data: { dialog_target: "focusTouch" }
  end
end
