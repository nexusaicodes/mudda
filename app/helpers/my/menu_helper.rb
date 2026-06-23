module My::MenuHelper
  def jump_field_tag
    text_field_tag :search, nil,
      type: "search",
      role: "combobox",
      placeholder: "Type to jump to a board or place…",
      class: "input input--transparent txt-small",
      autofocus: true,
      autocorrect: "off",
      autocomplete: "off",
      aria: { activedescendant: "" },
      data: {
        "1p-ignore": "true",
        dialog_target: "focusMouse",
        filter_target: "input",
        nav_section_expander_target: "input",
        navigable_list_target: "input",
        action: "input->filter#filter" }
  end

  def my_menu_board_item(board)
    my_menu_item("board", board) do
      link_to(tag.span(board.name, class: "overflow-ellipsis"), board, class: "popup__btn btn")
    end
  end

  def my_menu_filter_item(filter)
    my_menu_item("bookmark", filter) do
      link_to(cards_path(filter_id: filter.id), class: "popup__btn btn") do
        tag.div(class: "txt-tight-lines min-width txt-small overflow-ellipsis") do
          tag.div(tag.strong(filter.boards_label)) +
          tag.div(filter.summary, class: "txt-capitalize")
        end
      end
    end
  end

  def my_menu_item(item, record)
    tag.li(class: "popup__item", data: { filter_target: "item", navigable_list_target: "item", id: "filter-#{item}-#{record.id}" }) do
      icon_tag(item, class: "popup__icon") + yield
    end
  end
end
