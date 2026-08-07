class Message < ApplicationRecord
  belongs_to :conversation

  ROLES = %w[user assistant].freeze

  validates :role, presence: true, inclusion: { in: ROLES }
  validates :content, presence: true

  after_commit :broadcast_conversation_refresh, if: -> { role == "user" }

  private

  def broadcast_conversation_refresh
    broadcast_refresh_later_to(:conversation)
  end
end
