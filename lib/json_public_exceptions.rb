# The exceptions app: renders whatever escaped a controller. A JSON client gets the same
# { "errors": { … }, "request_id": "…" } envelope as every other failure (see JsonErrors) — an
# unknown route, a forged request, a crash — rather than Rails' { "status", "error" } body.
# Everything else gets the static pages in public/, with the request id added in both languages
# as a reference the user can quote.
class JsonPublicExceptions < ActionDispatch::PublicExceptions
  def call(env)
    request = ActionDispatch::Request.new(env)

    if json_request?(request)
      status = env["PATH_INFO"][1..].to_i
      message = Rack::Utils::HTTP_STATUS_CODES.fetch(status, "Error")
      body = { errors: { base: [ message ] }, request_id: request.request_id }.to_json

      [ status, { "content-type" => "application/json; charset=utf-8", "x-request-id" => request.request_id.to_s }, [ body ] ]
    else
      with_reference(*super, request.request_id)
    end
  end

  private
    def json_request?(request)
      request.formats.first&.json?
    rescue ActionDispatch::Http::MimeNegotiation::InvalidType
      false
    end

    def with_reference(status, headers, body, reference)
      if reference.present? && headers["content-type"].to_s.start_with?("text/html")
        html = body.join.sub("</hgroup>", "#{reference_note(reference)}\n    </hgroup>")
        [ status, headers.merge("content-length" => html.bytesize.to_s, "x-request-id" => reference), [ html ] ]
      else
        [ status, headers, body ]
      end
    end

    def reference_note(reference)
      code = "<code>#{ERB::Util.html_escape(reference)}</code>"
      %(<p class="error-page__reference">Reference: #{code}</p>\n      <p class="error-page__reference" lang="ar" dir="rtl">المرجع: #{code}</p>)
    end
end
