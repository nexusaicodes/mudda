module My::MenuHelper
  # One row of a header menu: an icon, a label, and either a tick for where you are or a count.
  def menu_item(label, path, icon:, current: false, count: nil, turbo: true)
    tag.li class: class_names("popup__item", "popup__item--current": current), aria: { current: current ? "page" : nil } do
      link_to path, class: "popup__btn btn", data: { turbo: turbo } do
        concat icon_tag(icon, class: "popup__icon")
        concat tag.span(label, class: "overflow-ellipsis flex-item-grow")
        concat icon_tag("check", class: "menu__check") if current
        concat tag.span(count, class: "menu__count") if count
      end
    end
  end
end
