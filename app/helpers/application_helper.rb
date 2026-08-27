module ApplicationHelper
  def page_title_tag
    tag.title [ @page_title, "Mudda" ].compact.join(" | ")
  end

  def icon_tag(name, **options)
    tag.span class: class_names("icon icon--#{name}", options.delete(:class)), "aria-hidden": true, **options
  end

  # The single source of truth for the browser-local "last opened board" key.
  # Written by the `last-board` Stimulus controller and read by the landing page.
  def last_board_storage_key(account = Current.account)
    "mudda:last-board:#{account.external_account_id}"
  end

  def back_link_to(label, url, action, prefer_referrer: [], **options)
    data = { controller: "hotkey", action: action }
    if prefer_referrer.any?
      data[:turbo_navigation_target] = "referrerBackLink"
      data[:turbo_navigation_allowed_referrer_paths] = prefer_referrer.join(",")
    end
    link_to url, class: "btn btn--back btn--circle-mobile", data: data, **options do
      icon_tag("arrow-left") + tag.strong("Back to #{label}", class: "overflow-ellipsis") + tag.kbd("ESC", class: "txt-x-small hide-on-touch").html_safe
    end
  end
end
