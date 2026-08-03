class CreateStandingIntents < ActiveRecord::Migration[8.1]
  def change
    create_table :standing_intents do |t|
      t.string   :visitor_id,          null: false
      t.string   :commodity_code,       null: false
      t.string   :description,          null: false
      t.string   :original_request,     null: false
      t.datetime :last_checked_at
      t.string   :last_result_digest
      t.boolean  :active, default: true, null: false
      t.timestamps
    end
    add_index :standing_intents, :visitor_id
  end
end
