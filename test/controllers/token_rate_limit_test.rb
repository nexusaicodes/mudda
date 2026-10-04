require "test_helper"

class TokenRateLimitTest < ActionDispatch::IntegrationTest
  test "a token past its allowance is refused with a 429 in the envelope, across endpoints" do
    headers = bearer_headers_for(:david)
    TokenRateLimit::STORE.write rate_limit_key(headers), TokenRateLimit::REQUESTS_PER_MINUTE, expires_in: 1.minute

    get boards_path(format: :json), headers: headers
    assert_response :too_many_requests
    assert_equal "60", @response.headers["Retry-After"]
    assert_match "Rate limit exceeded", @response.parsed_body.dig("errors", "base", 0)

    get cards_path(format: :json), headers: headers
    assert_response :too_many_requests
  end

  test "each token has its own allowance" do
    spent = bearer_headers_for(:david)
    TokenRateLimit::STORE.write rate_limit_key(spent), TokenRateLimit::REQUESTS_PER_MINUTE, expires_in: 1.minute

    get boards_path(format: :json), headers: bearer_headers_for(:david)
    assert_response :success
  end

  test "requests within the allowance are counted" do
    headers = bearer_headers_for(:david)

    3.times { get boards_path(format: :json), headers: headers }

    assert_equal 3, TokenRateLimit::STORE.read(rate_limit_key(headers)).to_i
  end

  test "a browser session isn't limited" do
    sign_in_as :david

    get board_path(boards(:writebook))

    assert_response :success
    assert_nil TokenRateLimit::STORE.read("rate-limit:token:#{users(:david).sessions.browser.last.id}")
  end

  private
    def rate_limit_key(headers)
      session = Session.token.find_signed(headers["Authorization"].delete_prefix("Bearer "))
      "rate-limit:token:#{session.id}"
    end
end
