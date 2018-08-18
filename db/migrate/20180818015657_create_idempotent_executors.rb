class CreateIdempotentExecutors < ActiveRecord::Migration[5.2]
  def change
    create_table :idempotent_executors do |t|
      t.references :user, foregin_key: true, null: false
      t.integer :transaction_type, null: false
      t.string :signature, null: false

      t.timestamps
    end
  end
end
