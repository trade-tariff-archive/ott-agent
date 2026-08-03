class CreateConversations < ActiveRecord::Migration[8.1]
  def change
    create_table :conversations do |t|
      t.string :visitor_id, null: false
      t.string :title, null: false
      t.timestamps
    end
    add_index :conversations, :visitor_id
  end
end
