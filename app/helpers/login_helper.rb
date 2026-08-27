module LoginHelper
  # Active Storage's controllers include Authentication but live in a mounted engine,
  # where bare route helpers resolve against the engine. main_app reaches the app's routes.
  def login_url
    main_app.new_session_path
  end

  def logout_url
    main_app.new_session_path
  end

  def redirect_to_login_url
    redirect_to login_url
  end

  def redirect_to_logout_url
    redirect_to logout_url
  end
end
