class ApplicationPushNotification < ActionPushNative::Notification
  queue_as :default
  self.enabled = Mudda.saas? && (!Rails.env.local? || ENV["ENABLE_NATIVE_PUSH"] == "true")
end
