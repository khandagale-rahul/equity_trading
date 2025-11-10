class ApiConfiguration < ApplicationRecord
  belongs_to :user

  enum :api_name, { zerodha: 1, upstox: 2, angel_one: 3 }

  validates :api_name, presence: true, uniqueness: { scope: :user_id, message: "has already been taken" }
  validates :api_key, presence: true
  validates :api_secret, presence: true

  def oauth_authorized?
    oauth_authorized_at.present? && access_token.present?
  end

  def token_expired?
    return true if token_expires_at.blank?
    token_expires_at < Time.current
  end

  def requires_reauthorization?
    !oauth_authorized? || token_expired?
  end

  def oauth_status
    return "Not Authorized" unless oauth_authorized?
    return "Token Expired" if token_expired?
    "Authorized"
  end

  def oauth_status_badge_class
    return "bg-secondary" unless oauth_authorized?
    return "bg-danger" if token_expired?
    "bg-success"
  end

  def generate_postback_url
    postback_base_url = Rails.application.credentials.postback_base_url
    return nil unless postback_base_url.present?

    "#{postback_base_url}/#{api_name}/postback/#{user_id}/#{id}"
  end
end
