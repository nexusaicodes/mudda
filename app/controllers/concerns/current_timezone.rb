# Reckons each request's dates in the user's time zone, so "today", "overdue", "due soon" and
# "created today" mean the owner's day wherever they are asked from:
#
# 1. the browser's own zone, from the `timezone` cookie its timezone-cookie controller sets;
# 2. else the zone saved from the browser last (user_settings.timezone_name, kept in sync by
#    layouts/shared/_time_zone), which is what a script or agent gets, since it sends no cookie,
#    and what a browser gets on the one request before its cookie is set;
# 3. else UTC.
#
# Timestamps on a page are rendered by the browser (local-time), so this decides dates the
# server works out: due-date labels and colours, overdue ordering, and the date filters.
module CurrentTimezone
  extend ActiveSupport::Concern

  included do
    around_action :set_current_timezone

    helper_method :timezone_from_cookie

    etag { timezone_for_request&.name }
  end

  private
    def set_current_timezone(&)
      Time.use_zone(timezone_for_request, &)
    end

    def timezone_for_request
      timezone_from_cookie || Current.user&.timezone
    end

    def timezone_from_cookie
      if cookies[:timezone].present?
        @timezone_from_cookie ||= User::Settings.timezone_named(cookies[:timezone])
      end
    end
end
