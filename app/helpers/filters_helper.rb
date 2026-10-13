module FiltersHelper
  def filter_title(title)
    tag.strong title, class: "popup__title pad-inline-half", tabindex: "-1", data: { dialog_target: "focusTouch" }
  end

  def nav_section(title, **properties, &block)
    tag.section class: "nav__section popup__section", **properties do
      concat tag.div(title, class: "popup__section-title")
      concat(tag.ul(class: "popup__list") do
        capture(&block)
      end)
    end
  end
end
