module AvatarsHelper
  AVATAR_FONT_PATH = Rails.root.join("app/assets/fonts/el-messiri-latin-wght-normal.woff2")

  def avatar_background_color(user)
    user.avatar_background_color
  end

  # An SVG shown through <img> can't fetch fonts, so the initials' face travels inside it.
  def avatar_font_data_uri
    AvatarsHelper.avatar_font_data_uri
  end

  def self.avatar_font_data_uri
    @avatar_font_data_uri ||= "data:font/woff2;base64,#{Base64.strict_encode64(AVATAR_FONT_PATH.binread)}"
  end

  def avatar_tag(user, hidden_for_screen_reader: false, **options)
    link_to user_path(user), class: class_names("avatar btn btn--circle", options.delete(:class)), data: { turbo_frame: "_top" },
      aria: { hidden: hidden_for_screen_reader, label: user.name },
      tabindex: hidden_for_screen_reader ? -1 : nil,
      **options do
      avatar_image_tag(user)
    end
  end

  def avatar_preview_tag(user, hidden_for_screen_reader: false, **options)
    tag.span class: class_names("avatar", options.delete(:class)),
      aria: { hidden: hidden_for_screen_reader, label: user.name },
      tabindex: hidden_for_screen_reader ? -1 : nil do
      avatar_image_tag(user, **options)
    end
  end

  def avatar_image_tag(user, **options)
    image_tag user_avatar_path(user), aria: { hidden: "true" }, size: 48, title: user.name, **options
  end
end
