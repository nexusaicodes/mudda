# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
# token covers access_token and refresh_token, secret covers client_secret, and authorization
# an Authorization header. OAuth's code and code_verifier are one-time credentials, and the
# owner's email is PII.
Rails.application.config.filter_parameters += %i[
  passw secret token _key crypt salt certificate otp ssn code code_verifier authorization email_address
]

# An OAuth redirect carries the authorization code (or, in other flows, a token) in its query.
Rails.application.config.filter_redirect << /[?&](code|access_token|refresh_token|token)=/
