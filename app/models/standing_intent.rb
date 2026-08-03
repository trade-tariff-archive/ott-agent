class StandingIntent < ApplicationRecord
  CHECK_INTERVAL = 6.hours

  validates :visitor_id,    presence: true
  validates :commodity_code, presence: true
  validates :description,   presence: true

  scope :active,        -> { where(active: true) }
  scope :for_visitor,   ->(id) { where(visitor_id: id) }
  scope :due_for_check, -> {
    active.where("last_checked_at IS NULL OR last_checked_at < ?", CHECK_INTERVAL.ago)
  }

  def needs_check?
    last_checked_at.nil? || last_checked_at < CHECK_INTERVAL.ago
  end
end
