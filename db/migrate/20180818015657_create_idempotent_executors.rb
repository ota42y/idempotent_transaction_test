class CreateIdempotentExecutors < ActiveRecord::Migration[5.2]
  def change
    create_table :idempotent_executors do |t|
      t.references :user, foreign_key: true, null: false
      t.integer :transaction_type, null: false
      t.string :signature, null: false

      t.timestamps

      t.index [:user_id, :transaction_type, :signature], unique: true, name: :idempotent_index
      t.index :created_at
    end
  end
end
