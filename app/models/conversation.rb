class Conversation < ApplicationRecord
  has_many :messages, dependent: :destroy

  validates :title, presence: true
  validates :visitor_id, presence: true

  scope :for_visitor, ->(id) { where(visitor_id: id) }

  def total_tokens
    messages.sum(:input_tokens) + messages.sum(:output_tokens)
  end
end
