class Message < ApplicationRecord
  belongs_to :conversation

  ROLES = %w[user assistant].freeze

  validates :role, presence: true, inclusion: { in: ROLES }
  validates :content, presence: true

end
