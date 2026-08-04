class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :authenticate
  before_action :ensure_visitor_id

  helper_method :visitor_id

private

  def visitor_id
    session[:visitor_id]
  end

  def ensure_visitor_id
    session[:visitor_id] ||= SecureRandom.uuid
  end

  def authenticate
    password = ENV.fetch("APP_PASSWORD", "dev123")
    authenticate_or_request_with_http_basic("OTT Agent") do |_username, given_password|
      ActiveSupport::SecurityUtils.secure_compare(given_password, password)
    end
  end
end
