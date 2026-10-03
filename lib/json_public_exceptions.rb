# The exceptions app: renders whatever escaped a controller. A JSON client gets the same
# { "errors": { … } } envelope as every other failure (see JsonErrors) — an unknown route, a
# forged request, a crash — rather than Rails' { "status", "error" } body. Everything else gets
# the static pages in public/, as before.
class JsonPublicExceptions < ActionDispatch::PublicExceptions
  def call(env)
    if json_request?(env)
      status = env["PATH_INFO"][1..].to_i
      message = Rack::Utils::HTTP_STATUS_CODES.fetch(status, "Error")

      [ status, { "content-type" => "application/json; charset=utf-8" }, [ { errors: { base: [ message ] } }.to_json ] ]
    else
      super
    end
  end

  private
    def json_request?(env)
      ActionDispatch::Request.new(env).formats.first&.json?
    rescue ActionDispatch::Http::MimeNegotiation::InvalidType
      false
    end
end
