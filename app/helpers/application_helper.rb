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
    # A pill on wider screens, the arrow alone in a circle on a phone; turbo-navigation rewrites the <strong>.
    link_to url, class: "back-link btn btn-ghost max-sm:btn-circle min-w-0", data: data, **options do
      icon_tag("arrow-left") + tag.strong(t("back_link.label", label: label), class: "truncate max-sm:sr-only")
    end
  end
end
