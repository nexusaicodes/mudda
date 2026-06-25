module AccessesHelper
  def access_menu_tag(board, **options, &)
    tag.menu class: [ options[:class], { "toggler--toggled": board.all_access? } ], data: {
      controller: "filter toggle-class navigable-list",
      action: "keydown->navigable-list#navigate filter:changed->navigable-list#reset",
      navigable_list_focus_on_selection_value: true,
      navigable_list_actionable_items_value: true,
      toggle_class_toggle_class: "toggler--toggled" }, &
  end

  def access_toggles_for(users, selected:, disabled: false)
    render partial: "boards/access_toggle",
      collection: users, as: :user,
      locals: { selected: selected, disabled: disabled },
      cached: ->(user) { [ user, selected, disabled ] }
  end
end
