require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  browser_options = Selenium::WebDriver::Chrome::Options.new.tap do |opts|
    opts.add_argument("--window-size=1200,800")
    opts.add_argument("--disable-extensions")
    # Disable non-foreground tabs from getting a lower process priority
    opts.add_argument("--disable-renderer-backgrounding")
    # Normally, Chrome will treat a 'foreground' tab instead as backgrounded if the surrounding
    # window is occluded (aka visually covered) by another window. This flag disables that.
    opts.add_argument("--disable-backgrounding-occluded-windows")
    # Suppress all permission prompts by automatically denying them.
    opts.add_argument("--deny-permission-prompts")
    opts.add_argument("--enable-automation")
  end

  # With SELENIUM_REMOTE_URL set (e.g. http://selenium:4444), the browser runs in a Selenium
  # container instead of beside the app, so the app server listens on every interface and is
  # addressed by the local IP that routes to Selenium. The port is fixed so URL helpers can name
  # it, and offset per parallel worker so workers don't collide.
  if selenium_url = ENV["SELENIUM_REMOTE_URL"]
    selenium = URI(selenium_url)
    app_ip = UDPSocket.open { |socket| socket.connect(selenium.host, selenium.port); socket.addr.last }

    serve_app_on = ->(port) do
      Capybara.server_port = port
      Capybara.app_host = "http://#{app_ip}:#{port}"
    end

    Capybara.server_host = "0.0.0.0"
    serve_app_on.(3100)
    parallelize_setup { |worker| serve_app_on.(3101 + worker) }
  end

  Capybara.register_driver :chrome_headless do |app|
    browser_options.add_argument("--headless")

    if selenium_url
      Capybara::Selenium::Driver.new(app, browser: :remote, url: selenium_url, options: browser_options)
    else
      Capybara::Selenium::Driver.new(app, browser: :chrome, options: browser_options)
    end
  end

  Capybara.register_driver :chrome do |app|
    Capybara::Selenium::Driver.new(app, browser: :chrome, options: browser_options)
  end

  if ENV["SYSTEM_TESTS_BROWSER"]
    driven_by :chrome, screen_size: [ 1200, 1000 ]
  else
    driven_by :chrome_headless, screen_size: [ 1200, 1000 ]
  end

  private
    # Drives the real sign-in form: the owner password is the only way in, and
    # +owner_password+ comes from SessionTestHelper.
    def sign_in_as(user)
      visit new_session_url

      fill_in "email_address", with: user.email_address
      fill_in "password", with: owner_password
      find("#log_in").click

      # The landing page redirects (client-side) to the last/most-recent board.
      assert_current_path %r{/boards/}
    end

    # Narrows the window to a phone. The browser outlives the test, so pair it with
    # +back_on_a_desktop+ in a teardown.
    def on_a_phone
      page.current_window.resize_to(375, 812)
    end

    def back_on_a_desktop
      page.current_window.resize_to(1200, 1000)
    end

    def assert_no_horizontal_scroll
      assert page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth"),
        "The page scrolls sideways at #{page.evaluate_script("document.documentElement.clientWidth")}px"
    end

    # The editor is a custom element, so Capybara's fill_in cannot reach it.
    def fill_in_lexxy(selector = "lexxy-editor", with:)
      editor_element = find(selector)
      editor_element.set with
      page.execute_script("arguments[0].value = '#{with}'", editor_element)
    end
end
