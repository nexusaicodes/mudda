module My::MenuHelper
  # A titled group of menu rows.
  def nav_section(title, **properties, &block)
    tag.section class: "nav__section popup__section", **properties do
      concat tag.div(title, class: "popup__section-title")
      concat(tag.ul(class: "popup__list") do
        capture(&block)
      end)
    end
  end

  # One row of a header menu: an icon, a label, and either a tick for where you are or a count.
  # +dir+ sets the label's text direction, for labels the user typed (dir: "auto").
  def menu_item(label, path, icon:, current: false, count: nil, turbo: true, dir: nil)
    tag.li class: class_names("popup__item", "popup__item--current": current), aria: { current: current ? "page" : nil } do
      link_to path, class: "popup__btn btn", data: { turbo: turbo } do
        concat icon_tag(icon, class: "popup__icon")
        concat tag.span(label, class: "overflow-ellipsis flex-item-grow", dir: dir)
        concat icon_tag("check", class: "menu__check") if current
        concat tag.span(count, class: "menu__count") if count
      end
    end
  end
end
