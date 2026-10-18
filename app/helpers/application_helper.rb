module ApplicationHelper
  def page_title_tag
    tag.title [ @page_title, "Mudda" ].compact.join(" | ")
  end

  def icon_tag(name, **options)
    tag.span class: class_names("icon icon--#{name}", options.delete(:class)), "aria-hidden": true, **options
  end

  def back_link_to(label, url, action: nil, prefer_referrer: [], **options)
    data = { action: action }
    if prefer_referrer.any?
      data[:turbo_navigation_target] = "referrerBackLink"
      data[:turbo_navigation_allowed_referrer_paths] = prefer_referrer.join(",")
    end
    link_to url, class: "btn btn--back btn--circle-mobile", data: data, **options do
      icon_tag("arrow-left") + tag.strong(t("back_link.label", label: label), class: "overflow-ellipsis")
    end
  end
end
