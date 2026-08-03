class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.string :role, null: false
      t.text :content, null: false
      t.integer :input_tokens,       default: 0, null: false
      t.integer :output_tokens,      default: 0, null: false
      t.float   :latency_seconds,    default: 0.0, null: false
      t.timestamps
    end
  end
end
