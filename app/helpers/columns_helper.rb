module ColumnsHelper
  # A lane's name for display; the stored name stays English for data attributes and the API.
  def lane_name(column)
    t("lanes.#{column.name.downcase}")
  end

  def button_to_set_column(card, column)
    current = column == card.column
    button_to \
      tag.span(lane_name(column), class: "truncate"),
      board_card_column_path(card.board, card, column_id: column.id),
      method: :patch,
      # The current lane is disabled but keeps its colour, overriding daisyUI's greyed-out look.
      class: [ "card__column-name btn btn-sm join-item w-full", { "card__column-name--current disabled:bg-(--column-color)! disabled:text-[oklch(from_var(--column-color)_round(1.15-l)_0_0)]! disabled:border-transparent!": current } ],
      disabled: current,
      aria: { checked: current },
      role: "radio",
      style: "--column-color: #{column.color}",
      form_class: "contents",
      data: { turbo_frame: "_top", scroll_to_target: current ? "target" : nil }
  end

  def column_tag(id:, name:, drop_url:, collapsed: true, selected: nil, card_color: "var(--color-card-default)", data: {}, **properties, &block)
    classes = token_list("cards", properties.delete(:class), "is-collapsed": collapsed, "is-expanded": !collapsed)

    data = {
      drag_and_drop_target: "container",
      navigable_list_target: "item",
      column_name: name,
      drag_and_drop_url: drop_url,
      drag_and_drop_css_variable_name: "--card-color",
      drag_and_drop_css_variable_value: card_color
    }.merge(data)

    data[:action] = token_list(
      "turbo:before-morph-attribute->collapsible-columns#preventToggle",
      "focus->navigable-list#select",
      data.delete(:action)
    )

    tag.section(id: id, class: classes, tabindex: "0", "aria-selected": selected, data: data, **properties) do
      tag.div(class: "cards__transition-container", data: {
        controller: "navigable-list",
        navigable_list_supports_horizontal_navigation_value: "false",
        navigable_list_prevent_handled_keys_value: "true",
        navigable_list_auto_select_value: "false",
        navigable_list_actionable_items_value: "true",
        navigable_list_only_act_on_focused_items_value: "true",
        action: "keydown->navigable-list#navigate"
      }, &block)
    end
  end

  def column_frame_tag(id, src: nil, data: {}, **options, &block)
    data = data.with_defaults \
      drag_and_drop_refresh: true,
      controller: "frame",
      action: "turbo:before-frame-render->frame#morphRender turbo:before-morph-element->frame#morphReload"
    options[:refresh] = :morph if src.present?
    turbo_frame_tag(id, src: src, data: data, **options, &block)
  end
end
